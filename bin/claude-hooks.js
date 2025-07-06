#!/usr/bin/env node

import { program } from 'commander';
import { exec } from '../lib/commands/exec.js';
import { init } from '../lib/commands/init.js';
import { list } from '../lib/commands/list.js';
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
  .action(() => init({ customMode: true }));

program.parse();