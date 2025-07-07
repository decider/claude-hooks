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
  
  // Context management
  'claude-context-updater': {
    event: 'PostToolUse',
    matcher: 'Write|Edit|MultiEdit',
    description: 'Updates CLAUDE.md context file'
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
  if (!existsSync(settingsPath)) return 0;
  
  try {
    const settings: HookSettings = JSON.parse(readFileSync(settingsPath, 'utf-8'));
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
function saveSettings(path: string, settings: HookSettings): void {
  // Create directory if needed
  const dir = join(path, '..');
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  
  // Save settings
  writeFileSync(path, JSON.stringify(settings, null, 2));
}

export async function manage(): Promise<void> {
  let selectedPath: string | null = null;
  
  while (true) {
    console.clear();
    console.log(chalk.cyan('Claude Hooks Manager\n'));
    
    if (!selectedPath) {
      // Display hook statistics before location selection
      const allStats = getAllHookStats();
      if (allStats.length > 0) {
        console.log(chalk.yellow('Hook Statistics:'));
        console.log(chalk.gray('─'.repeat(50)));
        console.log(chalk.gray('Hook Name'.padEnd(30) + 'Calls'.padEnd(10) + 'Last Called'));
        console.log(chalk.gray('─'.repeat(50)));
        
        allStats.forEach(stat => {
          const name = stat.name.padEnd(30);
          const calls = stat.count.toString().padEnd(10);
          const lastCall = stat.relativeTime;
          console.log(`${name}${calls}${lastCall}`);
        });
        console.log(chalk.gray('─'.repeat(50)));
        console.log();
      }
      
      // Show locations with hook counts
      const locations = SETTINGS_LOCATIONS.map(loc => {
        const count = countHooks(loc.path);
        return {
          name: `${chalk.cyan(loc.display)} ${chalk.gray(`(${count} hooks)`)} - ${chalk.gray(loc.description)}`,
          value: loc.path,
          short: loc.display
        };
      });
      
      // Add log viewing options
      const choices: any[] = [...locations];
      choices.push(new inquirer.Separator());
      choices.push({
        name: chalk.gray('📋 View recent logs'),
        value: 'view-logs'
      });
      choices.push({
        name: chalk.gray('📊 Tail logs (live)'),
        value: 'tail-logs'
      });
      
      const { path } = await inquirer.prompt([
        {
          type: 'list',
          name: 'path',
          message: 'Select a settings file to manage:',
          choices
        }
      ]);
      
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
        await inquirer.prompt([{ type: 'input', name: 'continue', message: '' }]);
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
          await inquirer.prompt([{ type: 'input', name: 'continue', message: '' }]);
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
    
    if (selectedPath && existsSync(selectedPath)) {
      try {
        settings = JSON.parse(readFileSync(selectedPath, 'utf-8'));
      } catch (err: any) {
        console.error(chalk.red(`Error reading ${selectedPath}: ${err.message}`));
        return;
      }
    }
  
    // Management loop for this file
    let managingFile = true;
    while (managingFile) {
      console.clear();
      console.log(chalk.cyan(`Managing: ${selectedPath}\n`));
      
      // Get current hooks
      const currentHooks = getHooksFromSettings(settings);
      const currentHookNames = new Set(currentHooks.map(h => h.name));
      
      // Get available hooks (not already added)
      const availableHooks = Object.entries(AVAILABLE_HOOKS)
        .filter(([name]) => !currentHookNames.has(name))
        .map(([name, config]) => ({ name, ...config }));
      
      // Build choices
      const choices: any[] = [];
      
      if (currentHooks.length > 0) {
        choices.push(new inquirer.Separator(
          chalk.yellow(`=== Current Hooks (${currentHooks.length}) ${chalk.gray('- press Enter to remove')} ===`)
        ));
        
        // Add "Remove all" option if there are multiple hooks
        if (currentHooks.length > 1) {
          choices.push({
            name: `${chalk.red('✗')} ${chalk.bold('Remove all hooks')} ${chalk.gray(`(${currentHooks.length} hooks)`)}`,
            value: { action: 'removeAll' }
          });
        }
        
        currentHooks.forEach((hook) => {
          const execInfo = hook.stats.count > 0 ? ` ${chalk.cyan(`[${hook.stats.count}x]`)}` : '';
          choices.push({
            name: `${chalk.red('✗')} ${hook.name} - ${hook.description} ${chalk.gray(`(${hook.event})`)}${execInfo}`,
            value: { action: 'remove', hook }
          });
        });
      }
      
      if (availableHooks.length > 0) {
        choices.push(new inquirer.Separator(
          chalk.green(`\n=== Available Hooks (${availableHooks.length}) ${chalk.gray('- press Enter to add')} ===`)
        ));
        
        // Add "Add all" option if there are multiple available hooks
        if (availableHooks.length > 1) {
          choices.push({
            name: `${chalk.green('⊕')} ${chalk.bold('Add all available hooks')} ${chalk.gray(`(${availableHooks.length} hooks)`)}`,
            value: { action: 'addAll' }
          });
        }
        
        availableHooks.forEach(hook => {
          choices.push({
            name: `${chalk.green('+')} ${hook.name} - ${hook.description} ${chalk.gray(`(${hook.event})`)}`,
            value: { action: 'add', hookName: hook.name }
          });
        });
      }
      
      choices.push(new inquirer.Separator());
      choices.push({ name: chalk.gray('← Back to location selection'), value: { action: 'back' } });
    
      const { selection } = await inquirer.prompt([
        {
          type: 'list',
          name: 'selection',
          message: 'Select an action:',
          choices,
          pageSize: 20
        }
      ]);
    
      switch (selection.action) {
        case 'remove':
          removeHook(settings, selection.hook);
          // Auto-save after each change
          if (selectedPath) saveSettings(selectedPath, settings);
          break;
          
        case 'removeAll':
          // Remove all hooks
          settings.hooks = {};
          if (selectedPath) saveSettings(selectedPath, settings);
          break;
          
        case 'add':
          addHook(settings, selection.hookName);
          // Auto-save after each change
          if (selectedPath) saveSettings(selectedPath, settings);
          break;
          
        case 'addAll':
          availableHooks.forEach(hook => {
            addHook(settings, hook.name);
          });
          if (selectedPath) saveSettings(selectedPath, settings);
          break;
          
        case 'back':
          managingFile = false;
          selectedPath = null;
          break;
      }
    }
  }
}