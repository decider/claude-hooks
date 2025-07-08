#!/usr/bin/env node

import { program } from 'commander';
import { exec } from './commands/exec.js';
import { init } from './commands/init.js';
import { list } from './commands/list.js';
import { manage } from './commands/manage.js';
import { validate } from './commands/validate.js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const packageJson = JSON.parse(readFileSync(join(__dirname, '../package.json'), 'utf-8'));

program
  .name('claude-hooks')
  .description('CLI for Claude Code hooks')
  .version(packageJson.version);

program
  .command('exec <hook>')
  .description('Execute a hook (used by Claude via npx)')
  .option('--files <files>', 'Comma-separated list of files to process')
  .option('--exclude <patterns>', 'Comma-separated list of patterns to exclude')
  .option('--include <patterns>', 'Comma-separated list of patterns to include')
  .action(exec);

program
  .command('init')
  .description('Initialize Claude hooks - choose quick setup or custom configuration')
  .option('-l, --level <level>', 'Configuration level: project, project-alt, local, or global')
  .action(init);

program
  .command('list')
  .description('List available hooks')
  .action(list);

program
  .command('manage')
  .description('Interactively manage hooks in settings.json files')
  .action(manage);

program
  .command('validate [path]')
  .description('Validate hook settings files')
  .option('-v, --verbose', 'Show detailed validation information')
  .option('--fix', 'Automatically fix issues (not yet implemented)')
  .action(validate);

// Default to manage command if no arguments provided
if (process.argv.length === 2) {
  process.argv.push('manage');
}

program.parse();