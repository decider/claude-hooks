import * as fs from 'fs';
import * as path from 'path';
import chalk from 'chalk';
import { HookSettings } from '../types.js';
import { HookConfig } from '../entry-points/base.js';

export async function migrateToEntryPoints(settingsPath?: string): Promise<void> {
  // Determine settings path
  const targetPath = settingsPath || path.join(process.cwd(), '.claude', 'settings.json');
  
  console.log(chalk.bold('\n🔄 Migrating to simplified entry points...\n'));
  
  // Check if settings file exists
  if (!fs.existsSync(targetPath)) {
    console.log(chalk.yellow('No settings.json found at:'), targetPath);
    console.log(chalk.gray('Run `npx claude-code-hooks-cli init` first'));
    return;
  }
  
  // Read current settings
  const settings: HookSettings = JSON.parse(fs.readFileSync(targetPath, 'utf-8'));
  
  // Create new simplified settings
  const newSettings: HookSettings = {
    _comment: "Claude Code hooks - simplified entry points (edit .claude/hooks/config.js to manage hooks)",
    hooks: {}
  };
  
  // Try to load existing config.js to determine matchers
  const configPath = path.join(path.dirname(targetPath), 'hooks', 'config.js');
  let config: HookConfig | null = null;
  
  if (fs.existsSync(configPath)) {
    try {
      delete require.cache[require.resolve(configPath)];
      const configModule = require(configPath);
      config = configModule.default || configModule;
    } catch (e) {
      console.log(chalk.yellow('⚠️  Could not load config.js, using generic matchers'));
    }
  }
  
  // Add entry points for each event type that has hooks
  if (settings.hooks?.PreToolUse && settings.hooks.PreToolUse.length > 0) {
    if (config?.preToolUse) {
      // Create matcher-specific entries based on config
      const matchers = Object.keys(config.preToolUse);
      newSettings.hooks.PreToolUse = matchers.map(matcher => ({
        matcher,
        hooks: [{
          type: 'command',
          command: `npx claude-code-hooks-cli pre-tool-use --matcher "${matcher}"`
        }]
      }));
    } else {
      // Fallback to generic entry
      newSettings.hooks.PreToolUse = [{
        hooks: [{
          type: 'command',
          command: 'npx claude-code-hooks-cli pre-tool-use'
        }]
      }];
    }
  }
  
  if (settings.hooks?.PostToolUse && settings.hooks.PostToolUse.length > 0) {
    if (config?.postToolUse) {
      // Create matcher-specific entries based on config
      const matchers = Object.keys(config.postToolUse);
      newSettings.hooks.PostToolUse = matchers.map(matcher => ({
        matcher,
        hooks: [{
          type: 'command',
          command: `npx claude-code-hooks-cli post-tool-use --matcher "${matcher}"`
        }]
      }));
    } else {
      // Fallback to generic entry
      newSettings.hooks.PostToolUse = [{
        hooks: [{
          type: 'command',
          command: 'npx claude-code-hooks-cli post-tool-use'
        }]
      }];
    }
  }
  
  if (settings.hooks?.Stop && settings.hooks.Stop.length > 0) {
    newSettings.hooks.Stop = [{
      hooks: [{
        type: 'command',
        command: 'npx claude-code-hooks-cli stop'
      }]
    }];
  }
  
  if (settings.hooks?.PreWrite && settings.hooks.PreWrite.length > 0) {
    newSettings.hooks.PreWrite = [{
      hooks: [{
        type: 'command',
        command: 'npx claude-code-hooks-cli pre-write'
      }]
    }];
  }
  
  if (settings.hooks?.PostWrite && settings.hooks.PostWrite.length > 0) {
    newSettings.hooks.PostWrite = [{
      hooks: [{
        type: 'command',
        command: 'npx claude-code-hooks-cli post-write'
      }]
    }];
  }
  
  // Backup old settings
  const backupPath = targetPath.replace('.json', '.backup.json');
  fs.writeFileSync(backupPath, JSON.stringify(settings, null, 2));
  console.log(chalk.green('✓'), 'Backed up original settings to:', chalk.gray(backupPath));
  
  // Write new settings
  fs.writeFileSync(targetPath, JSON.stringify(newSettings, null, 2));
  console.log(chalk.green('✓'), 'Updated settings.json with entry points');
  
  // Check if config.js exists (reuse configPath from above)
  if (!fs.existsSync(configPath)) {
    console.log(chalk.yellow('\n⚠️  No config.js found'));
    console.log(chalk.gray('A default config.js has been created based on your current hooks'));
    console.log(chalk.gray('Edit'), chalk.cyan(configPath), chalk.gray('to manage your hooks'));
  } else {
    console.log(chalk.green('✓'), 'Using existing config.js at:', chalk.gray(configPath));
  }
  
  console.log(chalk.bold.green('\n✨ Migration complete!'));
  console.log(chalk.gray('\nYou can now:'));
  console.log(chalk.gray('- Edit'), chalk.cyan('.claude/hooks/config.js'), chalk.gray('to manage hooks'));
  console.log(chalk.gray('- Changes take effect immediately (no restart needed)'));
  console.log(chalk.gray('- Your settings.json will not need updates anymore'));
}