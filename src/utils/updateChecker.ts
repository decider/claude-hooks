import { exec } from 'child_process';
import { promisify } from 'util';
import chalk from 'chalk';

const execAsync = promisify(exec);

interface UpdateCheckResult {
  updateAvailable: boolean;
  currentVersion: string;
  latestVersion: string;
}

export async function checkForUpdates(currentVersion: string, packageName: string): Promise<UpdateCheckResult | null> {
  try {
    // Get latest version from npm with a 2 second timeout
    const { stdout } = await execAsync(`npm view ${packageName} version`, { 
      encoding: 'utf8',
      timeout: 2000 
    });
    
    const latestVersion = stdout.trim();
    const updateAvailable = compareVersions(currentVersion, latestVersion) < 0;
    
    return {
      updateAvailable,
      currentVersion,
      latestVersion
    };
  } catch (error) {
    // Silently fail - don't interrupt user experience
    return null;
  }
}

function compareVersions(v1: string, v2: string): number {
  const parts1 = v1.split('.').map(Number);
  const parts2 = v2.split('.').map(Number);
  
  for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
    const part1 = parts1[i] || 0;
    const part2 = parts2[i] || 0;
    
    if (part1 < part2) return -1;
    if (part1 > part2) return 1;
  }
  
  return 0;
}

export function displayUpdateNotification(result: UpdateCheckResult): void {
  if (!result.updateAvailable) return;
  
  console.log();
  console.log(chalk.yellow('╔════════════════════════════════════════════════════════════╗'));
  console.log(chalk.yellow('║') + chalk.bold.white('  Update available! ') + chalk.gray(`${result.currentVersion} → `) + chalk.green(result.latestVersion) + '                       ' + chalk.yellow('║'));
  console.log(chalk.yellow('║') + chalk.gray('  Run ') + chalk.cyan('npm update -g claude-code-hooks-cli') + chalk.gray(' to update') + '     ' + chalk.yellow('║'));
  console.log(chalk.yellow('╚════════════════════════════════════════════════════════════╝'));
  console.log();
}