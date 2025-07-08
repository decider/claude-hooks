import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import chalk from 'chalk';
import inquirer from 'inquirer';
import { execSync } from 'child_process';
import { 
  HookConfigs, 
  HookSettings, 
  SettingsLocation, 
  HookInfo, 
  HookStats, 
  HookStatDisplay 
} from '../types.js';
import { SETTINGS_LOCATIONS } from '../settings-locations.js';
import { HookValidator } from '../validation/index.js';
import { HookSelector, HookChoice } from './hook-selector.js';
import { LocationSelector, LocationChoice } from './location-selector.js';

// Available hooks from the npm package
const AVAILABLE_HOOKS: HookConfigs = {
  // Single-purpose validation hooks
  'typescript-check': {
    event: 'PreToolUse',
    matcher: 'Bash',
    pattern: '^git\\s+commit',
    description: 'TypeScript type checking'
  },
  'lint-check': {
    event: 'PreToolUse',
    matcher: 'Bash',
    pattern: '^git\\s+commit',
    description: 'Code linting (ESLint, etc.)'
  },
  'test-check': {
    event: 'PreToolUse',
    matcher: 'Bash',
    description: 'Run test suite'
  },
  
  // Package management
  'check-package-age': {
    event: 'PreToolUse',
    matcher: 'Bash',
    pattern: '^(npm\\s+(install|i|add)|yarn\\s+(add|install))\\s+',
    description: 'Prevents installation of outdated npm/yarn packages'
  },
  
  // Code quality
  'code-quality-validator': {
    event: 'PostToolUse',
    matcher: 'Write|Edit|MultiEdit',
    description: 'Enforces clean code standards (function length, nesting, etc.)'
  },
  
  // Notifications
  'task-completion-notify': {
    event: 'PostToolUse',
    matcher: 'TodoWrite',
    description: 'System notifications for completed tasks'
  }
};


// Helper function to extract hook name from command
function extractHookName(command: string): string | null {
  const match = command.match(/exec\s+([a-z-]+)/);
  return match ? match[1] : null;
}

// Helper function to count hooks in a settings file
function countHooks(settingsPath: string): number {
  // Convert relative paths to absolute
  const absolutePath = settingsPath.startsWith('/') || settingsPath.startsWith(process.env.HOME || '') 
    ? settingsPath 
    : join(process.cwd(), settingsPath);
    
  if (!existsSync(absolutePath)) return 0;
  
  try {
    const settings: HookSettings = JSON.parse(readFileSync(absolutePath, 'utf-8'));
    let count = 0;
    
    if (settings.hooks) {
      Object.values(settings.hooks).forEach(eventHooks => {
        if (Array.isArray(eventHooks)) {
          eventHooks.forEach(hookGroup => {
            if (hookGroup.hooks && Array.isArray(hookGroup.hooks)) {
              count += hookGroup.hooks.length;
            }
          });
        }
      });
    }
    
    return count;
  } catch (err) {
    return 0;
  }
}

// Helper function to format relative time
function formatRelativeTime(dateStr: string | null): string {
  if (!dateStr) return 'Never';
  
  const date = new Date(dateStr);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSecs = Math.floor(diffMs / 1000);
  const diffMins = Math.floor(diffSecs / 60);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);
  
  if (diffDays > 0) return `${diffDays}d ago`;
  if (diffHours > 0) return `${diffHours}h ago`;
  if (diffMins > 0) return `${diffMins}m ago`;
  return 'Just now';
}

// Helper function to get hook stats from logs
function getHookStats(hookName: string): HookStats {
  try {
    const logFile = `${process.env.HOME}/.local/share/claude-hooks/logs/hooks.log`;
    if (!existsSync(logFile)) {
      return { count: 0, lastCall: null };
    }
    
    // Get execution count
    const count = parseInt(execSync(
      `grep -c "\\[${hookName}\\] Hook started" "${logFile}" 2>/dev/null || echo 0`,
      { encoding: 'utf-8' }
    ).trim()) || 0;
    
    if (count === 0) {
      return { count: 0, lastCall: null };
    }
    
    // Get last execution time
    const lastLine = execSync(
      `grep "\\[${hookName}\\] Hook" "${logFile}" 2>/dev/null | tail -1 || echo ""`,
      { encoding: 'utf-8' }
    ).trim();
    
    let lastCall: string | null = null;
    if (lastLine) {
      const match = lastLine.match(/\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]/);
      if (match) {
        lastCall = match[1];
      }
    }
    
    return { count, lastCall };
  } catch (error) {
    // If anything fails, return zeros
    return { count: 0, lastCall: null };
  }
}

// Helper function to get all hook statistics
function getAllHookStats(): HookStatDisplay[] {
  const hookStats: HookStatDisplay[] = [];
  
  // Get all available hooks
  Object.entries(AVAILABLE_HOOKS).forEach(([hookName, config]) => {
    const stats = getHookStats(hookName);
    if (stats.count > 0) {
      hookStats.push({
        name: hookName,
        count: stats.count,
        lastCall: stats.lastCall,
        relativeTime: formatRelativeTime(stats.lastCall)
      });
    }
  });
  
  // Sort by count (descending)
  return hookStats.sort((a, b) => b.count - a.count);
}

// Helper function to get all hooks from a settings file
function getHooksFromSettings(settings: HookSettings): HookInfo[] {
  const hooks: HookInfo[] = [];
  
  if (!settings.hooks) return hooks;
  
  Object.entries(settings.hooks).forEach(([event, eventHooks]) => {
    if (Array.isArray(eventHooks)) {
      eventHooks.forEach((hookGroup, groupIndex) => {
        if (hookGroup.hooks && Array.isArray(hookGroup.hooks)) {
          hookGroup.hooks.forEach((hook, hookIndex) => {
            const hookName = extractHookName(hook.command);
            if (hookName) {
              hooks.push({
                event,
                groupIndex,
                hookIndex,
                name: hookName,
                matcher: hookGroup.matcher,
                pattern: hookGroup.pattern,
                command: hook.command,
                description: AVAILABLE_HOOKS[hookName]?.description || 'No description',
                stats: getHookStats(hookName)
              });
            }
          });
        }
      });
    }
  });
  
  return hooks;
}

// Helper function to remove a hook from settings
function removeHook(settings: HookSettings, hookToRemove: HookInfo): void {
  const eventHooks = settings.hooks[hookToRemove.event];
  if (!eventHooks || !Array.isArray(eventHooks)) return;
  
  const hookGroup = eventHooks[hookToRemove.groupIndex];
  if (!hookGroup || !hookGroup.hooks) return;
  
  // Remove the hook
  hookGroup.hooks.splice(hookToRemove.hookIndex, 1);
  
  // If this was the last hook in the group, remove the group
  if (hookGroup.hooks.length === 0) {
    eventHooks.splice(hookToRemove.groupIndex, 1);
  }
}

// Helper function to add a hook to settings
function addHook(settings: HookSettings, hookName: string): void {
  const hookConfig = AVAILABLE_HOOKS[hookName];
  if (!hookConfig) return;
  
  // Ensure hooks structure exists
  if (!settings.hooks) settings.hooks = {};
  if (!settings.hooks[hookConfig.event]) settings.hooks[hookConfig.event] = [];
  
  const eventHooks = settings.hooks[hookConfig.event];
  
  // Find existing group with same matcher and pattern, or create new one
  let targetGroup = eventHooks.find(group => 
    group.matcher === hookConfig.matcher &&
    group.pattern === hookConfig.pattern
  );
  
  if (!targetGroup) {
    targetGroup = {
      hooks: []
    };
    if (hookConfig.matcher) targetGroup.matcher = hookConfig.matcher;
    if (hookConfig.pattern) targetGroup.pattern = hookConfig.pattern;
    eventHooks.push(targetGroup);
  }
  
  // Add the hook
  targetGroup.hooks.push({
    type: 'command',
    command: `npx claude-code-hooks-cli exec ${hookName}`
  });
}

// Helper function to save settings
function saveSettings(path: string, settings: HookSettings, silent: boolean = false): void {
  // Validate settings before saving
  const validator = new HookValidator();
  const result = validator.validateSettings(settings);
  
  if (!result.valid) {
    if (!silent) {
      console.error(chalk.red('\n❌ Invalid settings configuration:'));
      console.error(validator.formatResults(result, true));
      console.error(chalk.yellow('\nSettings were not saved due to validation errors.'));
    }
    throw new Error('Invalid settings configuration');
  }
  
  // Show warnings if any
  if (!silent && result.warnings.length > 0) {
    console.warn(chalk.yellow('\n⚠️  Validation warnings:'));
    result.warnings.forEach(warning => {
      console.warn(chalk.yellow(`  - ${warning.message}`));
    });
  }
  
  // Create directory if needed
  const dir = join(path, '..');
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  
  // Save settings
  writeFileSync(path, JSON.stringify(settings, null, 2));
}

export async function manage(): Promise<void> {
  // Ensure Ctrl+C always works
  process.on('SIGINT', () => {
    console.log(chalk.yellow('\n\nExiting...'));
    process.exit(0);
  });

  let selectedPath: string | null = null;
  
  while (true) {
    console.clear();
    console.log(chalk.cyan('Claude Hooks Manager\n'));
    
    if (!selectedPath) {
      // Get hook statistics
      const allStats = getAllHookStats();
      
      // Build location choices
      const locationChoices: LocationChoice[] = SETTINGS_LOCATIONS.map(loc => ({
        path: loc.path,
        display: loc.display,
        description: loc.description,
        hookCount: countHooks(loc.path),
        value: loc.path
      }));
      
      // Add separator
      locationChoices.push({
        path: '',
        display: '',
        description: '',
        hookCount: 0,
        value: 'separator'
      });
      
      // Add log viewing options
      locationChoices.push({
        path: '',
        display: chalk.gray('📋 View recent logs'),
        description: '',
        hookCount: 0,
        value: 'view-logs'
      });
      
      locationChoices.push({
        path: '',
        display: chalk.gray('📊 Tail logs (live)'),
        description: '',
        hookCount: 0,
        value: 'tail-logs'
      });
      
      // Add separator
      locationChoices.push({
        path: '',
        display: '',
        description: '',
        hookCount: 0,
        value: 'separator'
      });
      
      // Add exit option
      locationChoices.push({
        path: '',
        display: '✕ Exit',
        description: '',
        hookCount: 0,
        value: 'exit'
      });
      
      // Run the location selector
      const selector = new LocationSelector(locationChoices, allStats.length > 0, allStats);
      const path = await selector.run();
      
      if (path === 'exit') {
        console.log(chalk.yellow('Goodbye!'));
        process.exit(0);
      }
      
      if (path === 'view-logs') {
        console.clear();
        const logFile = `${process.env.HOME}/.local/share/claude-hooks/logs/hooks.log`;
        if (existsSync(logFile)) {
          console.log(chalk.yellow('Recent hook logs (last 50 lines):\n'));
          execSync(`tail -50 "${logFile}"`, { stdio: 'inherit' });
        } else {
          console.log(chalk.gray('No log file found.'));
        }
        console.log(chalk.gray('\nPress Enter to continue...'));
        try {
          await inquirer.prompt([{ type: 'input', name: 'continue', message: '' }]);
        } catch (err) {
          // User pressed Ctrl+C
          process.exit(0);
        }
        continue;
      }
      
      if (path === 'tail-logs') {
        console.clear();
        const logFile = `${process.env.HOME}/.local/share/claude-hooks/logs/hooks.log`;
        if (existsSync(logFile)) {
          console.log(chalk.yellow('Tailing hook logs (Ctrl+C to stop):\n'));
          try {
            execSync(`tail -f "${logFile}"`, { stdio: 'inherit' });
          } catch (e) {
            // User pressed Ctrl+C
          }
        } else {
          console.log(chalk.gray('No log file found.'));
          console.log(chalk.gray('\nPress Enter to continue...'));
          try {
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '' }]);
          } catch (err) {
            // User pressed Ctrl+C
            process.exit(0);
          }
        }
        continue;
      }
      
      selectedPath = path;
    }
  
    // Load or create settings
    let settings: HookSettings = {
      "_comment": "Claude Code hooks configuration (using claude-code-hooks-cli)",
      "hooks": {}
    };
    
    // Convert relative paths to absolute
    const absoluteSelectedPath = selectedPath && (selectedPath.startsWith('/') || selectedPath.startsWith(process.env.HOME || '') 
      ? selectedPath 
      : join(process.cwd(), selectedPath));
    
    if (absoluteSelectedPath && existsSync(absoluteSelectedPath)) {
      try {
        settings = JSON.parse(readFileSync(absoluteSelectedPath, 'utf-8'));
        
        // Validate loaded settings
        const validator = new HookValidator();
        const result = validator.validateSettings(settings);
        
        if (!result.valid) {
          console.error(chalk.red(`\n❌ Invalid settings in ${selectedPath}:`));
          console.error(validator.formatResults(result, true));
          console.error(chalk.yellow('\nPlease fix these issues before managing hooks.'));
          console.error(chalk.gray('\nPress Enter to continue...'));
          await inquirer.prompt([{ type: 'input', name: 'continue', message: '' }]);
          selectedPath = null;
          continue;
        }
        
        // Show warnings if any
        if (result.warnings.length > 0) {
          console.warn(chalk.yellow('\n⚠️  Validation warnings:'));
          result.warnings.forEach(warning => {
            console.warn(chalk.yellow(`  - ${warning.message}`));
          });
          console.warn(chalk.gray('\nPress Enter to continue...'));
          await inquirer.prompt([{ type: 'input', name: 'continue', message: '' }]);
        }
      } catch (err: any) {
        console.error(chalk.red(`Error reading ${selectedPath}: ${err.message}`));
        return;
      }
    }
  
    // Management loop for this file
    let managingFile = true;
    while (managingFile) {
      // Get current hooks
      const currentHooks = getHooksFromSettings(settings);
      const currentHookNames = new Set(currentHooks.map(h => h.name));
      
      // Build hook choices for the selector
      const hookChoices: HookChoice[] = Object.entries(AVAILABLE_HOOKS).map(([name, config]) => ({
        name,
        description: config.description,
        event: config.event,
        selected: currentHookNames.has(name)
      }));
      
      // Sort hooks: selected first, then by name
      hookChoices.sort((a, b) => {
        if (a.selected !== b.selected) return b.selected ? 1 : -1;
        return a.name.localeCompare(b.name);
      });
      
      // Create the save handler
      const saveHandler = async (selectedHookNames: string[]) => {
        // Clear hooks and rebuild based on selection
        settings.hooks = {};
        selectedHookNames.forEach(hookName => {
          addHook(settings, hookName);
        });
        
        if (absoluteSelectedPath) {
          try {
            saveSettings(absoluteSelectedPath, settings, true); // silent mode for auto-save
          } catch (err) {
            // Handle validation errors silently during auto-save
          }
        }
      };
      
      // Run the hook selector
      const selector = new HookSelector(hookChoices, saveHandler);
      const result = await selector.run();
      
      // If user cancelled (Ctrl+C, Q, or Esc), go back to location selection
      if (result === null) {
        managingFile = false;
        selectedPath = null;
      }
    }
  }
}