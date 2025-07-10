import fs from 'fs/promises';
import path from 'path';
import chalk from 'chalk';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const FIRST_RUN_FILE = path.join(process.env.HOME || '', '.claude-hooks-initialized');

export async function isFirstRun(): Promise<boolean> {
  try {
    await fs.access(FIRST_RUN_FILE);
    return false;
  } catch {
    return true;
  }
}

export async function markFirstRunComplete(): Promise<void> {
  await fs.writeFile(FIRST_RUN_FILE, new Date().toISOString());
}

export async function showWelcomeMessage(): Promise<void> {
  console.log();
  console.log(chalk.blue('╔════════════════════════════════════════════════════════════╗'));
  console.log(chalk.blue('║') + chalk.bold.white('  Welcome to Claude Hooks CLI! 🎉') + '                           ' + chalk.blue('║'));
  console.log(chalk.blue('║') + '                                                            ' + chalk.blue('║'));
  console.log(chalk.blue('║') + chalk.gray('  Manage validation and quality checks for Claude Code') + '     ' + chalk.blue('║'));
  console.log(chalk.blue('║') + '                                                            ' + chalk.blue('║'));
  console.log(chalk.blue('║') + chalk.white('  Quick start:') + '                                              ' + chalk.blue('║'));
  console.log(chalk.blue('║') + chalk.green('  • claude-hooks') + chalk.gray(' - Open the interactive manager') + '           ' + chalk.blue('║'));
  console.log(chalk.blue('║') + chalk.green('  • claude-hooks init') + chalk.gray(' - Set up hooks for your project') + '     ' + chalk.blue('║'));
  console.log(chalk.blue('║') + chalk.green('  • claude-hooks list') + chalk.gray(' - See all available hooks') + '           ' + chalk.blue('║'));
  console.log(chalk.blue('║') + '                                                            ' + chalk.blue('║'));
  console.log(chalk.blue('║') + chalk.gray('  Updates are checked automatically') + '                        ' + chalk.blue('║'));
  console.log(chalk.blue('╚════════════════════════════════════════════════════════════╝'));
  console.log();
}