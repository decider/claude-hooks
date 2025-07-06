import { writeFileSync, existsSync, mkdirSync, readFileSync } from 'fs';
import { join } from 'path';
import chalk from 'chalk';
import inquirer from 'inquirer';
import { manage } from './manage.js';
import { HookSettings, SettingsLocation } from '../types.js';
import { SETTINGS_LOCATIONS } from '../settings-locations.js';

const DEFAULT_SETTINGS: HookSettings = {
  "_comment": "Claude Code hooks configuration (using claude-code-hooks-cli)",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "pattern": "^(npm\\s+(install|i|add)|yarn\\s+(add|install))\\s+",
        "hooks": [
          {
            "type": "command",
            "command": "npx claude-code-hooks-cli exec check-package-age"
          }
        ]
      },
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "npx claude-code-hooks-cli exec code-quality-primer"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit", 
        "hooks": [
          {
            "type": "command",
            "command": "npx claude-code-hooks-cli exec code-quality-validator"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "npx claude-code-hooks-cli exec stop-validation"
          }
        ]
      }
    ]
  }
};

// Settings file locations

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

async function quickSetup(location: SettingsLocation): Promise<void> {
  const targetDir = location.dir;
  const fileName = location.file;
  const settingsPath = join(targetDir, fileName);

  // Create directory if it doesn't exist
  if (!existsSync(targetDir)) {
    mkdirSync(targetDir, { recursive: true });
  }

  // Check if settings already exist
  if (existsSync(settingsPath)) {
    const { overwrite } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'overwrite',
        message: chalk.yellow(`Settings already exist at ${settingsPath}. Overwrite?`),
        default: false
      }
    ]);

    if (!overwrite) {
      console.log(chalk.gray('Cancelled.'));
      return;
    }
  }

  // Write settings
  writeFileSync(settingsPath, JSON.stringify(DEFAULT_SETTINGS, null, 2));
  
  console.log();
  console.log(chalk.green(`✓ Created ${settingsPath}`));
  console.log();
  console.log('Hooks configured:');
  console.log('  • Package age validation (npm/yarn install)');
  console.log('  • Code quality validation (file edits)');
  console.log('  • TypeScript/lint validation (before stop)');
  console.log();
  console.log(chalk.cyan('Next steps:'));
  console.log(`  1. Install this package: ${chalk.white('npm install -D claude-code-hooks-cli')}`);
  console.log(`  2. Hooks will run automatically in Claude Code`);
  console.log(`  3. Run ${chalk.white('npx claude-code-hooks-cli init')} again to customize`);
}

interface InitOptions {
  level?: string;
  customMode?: boolean;
}

export async function init(options: InitOptions): Promise<void> {
  // If custom mode is explicitly requested (from manage alias), go straight to manage
  if (options.customMode) {
    return manage();
  }

  let selectedLocation: SettingsLocation | undefined;

  // If level option is provided, find the corresponding location
  if (options.level) {
    selectedLocation = SETTINGS_LOCATIONS.find(loc => loc.level === options.level);
    if (!selectedLocation) {
      console.error(chalk.red(`Invalid level: ${options.level}`));
      console.log(chalk.yellow('Valid options: project, project-alt, local, global'));
      process.exit(1);
    }
  } else {
    // First, ask about setup mode
    const { setupMode } = await inquirer.prompt([
      {
        type: 'list',
        name: 'setupMode',
        message: 'How would you like to set up hooks?',
        choices: [
          {
            name: `${chalk.cyan('Quick setup')} ${chalk.gray('(recommended defaults)')}`,
            value: 'quick'
          },
          {
            name: `${chalk.cyan('Custom setup')} ${chalk.gray('(choose your hooks)')}`,
            value: 'custom'
          }
        ],
        default: 0
      }
    ]);

    if (setupMode === 'custom') {
      // Go to manage interface
      return manage();
    }

    // Quick setup - ask for location
    const locations = SETTINGS_LOCATIONS.map(loc => {
      const count = countHooks(loc.path);
      const existsText = count > 0 ? ` ${chalk.yellow(`(exists with ${count} hooks)`)}` : '';
      return {
        name: `${chalk.cyan(loc.display)} ${chalk.gray(loc.description)}${existsText}`,
        value: loc
      };
    });

    const { location } = await inquirer.prompt([
      {
        type: 'list',
        name: 'location',
        message: 'Where would you like to create the settings file?',
        choices: locations,
        default: 0
      }
    ]);
    selectedLocation = location;
  }

  // Proceed with quick setup
  if (selectedLocation) {
    await quickSetup(selectedLocation);
  }
}