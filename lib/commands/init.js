import { writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import chalk from 'chalk';
import inquirer from 'inquirer';

const DEFAULT_SETTINGS = {
  "_comment": "Claude Code hooks configuration (using claude-code-hooks-cli)",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "pattern": "^(npm\\s+(install|i)|yarn\\s+add)\\s+",
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

export async function init(options) {
  const locations = [
    { 
      name: `${chalk.cyan('.claude/settings.json')} ${chalk.gray('(Team settings - git tracked)')}`,
      value: { dir: './.claude', file: 'settings.json' },
      short: '.claude/settings.json'
    },
    { 
      name: `${chalk.cyan('claude/settings.json')} ${chalk.gray('(Team settings - git tracked, no dot prefix)')}`,
      value: { dir: './claude', file: 'settings.json' },
      short: 'claude/settings.json'
    },
    { 
      name: `${chalk.cyan('.claude/settings.local.json')} ${chalk.gray('(Personal settings - git ignored)')}`,
      value: { dir: './.claude', file: 'settings.local.json' },
      short: '.claude/settings.local.json'
    },
    { 
      name: `${chalk.cyan('~/.claude/settings.json')} ${chalk.gray('(Global - all projects)')}`,
      value: { dir: `${process.env.HOME}/.claude`, file: 'settings.json' },
      short: '~/.claude/settings.json'
    }
  ];

  let selectedLocation;

  // If level option is provided, use it without prompting
  if (options.level && options.level !== 'project') {
    switch (options.level) {
      case 'project':
        selectedLocation = locations[0].value;
        break;
      case 'project-alt':
        selectedLocation = locations[1].value;
        break;
      case 'local':
        selectedLocation = locations[2].value;
        break;
      case 'global':
        selectedLocation = locations[3].value;
        break;
      default:
        console.error(chalk.red(`Invalid level: ${options.level}`));
        console.log(chalk.yellow('Valid options: project, project-alt, local, global'));
        process.exit(1);
    }
  } else {
    // Interactive prompt
    const answer = await inquirer.prompt([
      {
        type: 'list',
        name: 'location',
        message: 'Where would you like to create the settings file?',
        choices: locations,
        default: 0
      }
    ]);
    selectedLocation = answer.location;
  }

  const targetDir = selectedLocation.dir;
  const fileName = selectedLocation.file;
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
  console.log(`  3. Run ${chalk.white('npx claude-code-hooks-cli list')} to see all available hooks`);
}