import { readdirSync, readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import chalk from 'chalk';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const HOOK_DESCRIPTIONS = {
  'check-package-age': 'Prevents installation of outdated npm/yarn packages',
  'stop-validation': 'Validates TypeScript and linting before allowing Claude to stop',
  'code-quality-validator': 'Enforces clean code standards on file edits',
  'code-quality-primer': 'Provides code quality context before edits',
  'pre-commit-check': 'Runs checks before git commits',
  'claude-context-updater': 'Updates CLAUDE.md context file',
  'task-completion-notify': 'System notifications for completed tasks',
  'code-similarity-check': 'Detects duplicate code',
  'post-write': 'Runs after file writes',
  'pre-completion-check': 'Validates before marking todos complete'
};

export async function list() {
  const hooksDir = join(__dirname, '../../hooks');
  
  console.log(chalk.cyan('Available Claude Hooks:\n'));
  
  try {
    const files = readdirSync(hooksDir);
    const hooks = files
      .filter(f => f.endsWith('.sh'))
      .map(f => f.replace('.sh', ''))
      .filter(h => !h.includes('common')); // Exclude common libraries
    
    hooks.forEach(hook => {
      const description = HOOK_DESCRIPTIONS[hook] || 'No description available';
      console.log(`  ${chalk.green('•')} ${chalk.white(hook)}`);
      console.log(`    ${chalk.gray(description)}`);
      console.log(`    Usage: ${chalk.yellow(`npx @claude-hooks/cli exec ${hook}`)}`);
      console.log();
    });
    
    console.log(chalk.cyan('Add to settings.json:'));
    console.log(chalk.gray('  Run `npx claude-hooks init` to generate a complete configuration'));
    
  } catch (err) {
    console.error(chalk.red('Error reading hooks directory:'), err.message);
    process.exit(1);
  }
}