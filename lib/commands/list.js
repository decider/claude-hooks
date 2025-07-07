import { readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import chalk from 'chalk';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const HOOK_DESCRIPTIONS = {
    // Single-purpose validation hooks
    'typescript-check': 'TypeScript type checking',
    'lint-check': 'Code linting (ESLint, etc.)',
    'test-check': 'Run test suite',
    // Feature hooks
    'check-package-age': 'Prevents installation of outdated npm/yarn packages',
    'code-quality-validator': 'Enforces clean code standards (function length, nesting, etc.)',
    'claude-context-updater': 'Updates CLAUDE.md context file',
    'task-completion-notify': 'System notifications for completed tasks',
    // Legacy hooks (still exist but not recommended)
    'stop-validation': '[LEGACY] Validates TypeScript/lint before stop - use individual checks instead',
    'validate-code': '[LEGACY] Use typescript-check and lint-check instead',
    'validate-on-completion': '[LEGACY] Use typescript-check and lint-check instead'
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
            console.log(`    Usage: ${chalk.yellow(`npx claude-code-hooks-cli exec ${hook}`)}`);
            console.log();
        });
        console.log(chalk.cyan('Add to settings.json:'));
        console.log(chalk.gray('  Run `npx claude-code-hooks-cli init` to set up hooks'));
        console.log(chalk.gray('  Run `npx claude-code-hooks-cli manage` to manage existing hooks'));
    }
    catch (err) {
        console.error(chalk.red('Error reading hooks directory:'), err.message);
        process.exit(1);
    }
}
//# sourceMappingURL=list.js.map