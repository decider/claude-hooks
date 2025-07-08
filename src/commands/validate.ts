import { existsSync } from 'fs';
import { resolve, basename } from 'path';
import chalk from 'chalk';
import { HookValidator } from '../validation/index.js';
import { SETTINGS_LOCATIONS } from '../settings-locations.js';

interface ValidateOptions {
  verbose?: boolean;
  fix?: boolean;
}

export async function validate(path?: string, options: ValidateOptions = {}): Promise<void> {
  const validator = new HookValidator();
  
  // Find files to validate
  let files: string[] = [];
  
  if (path) {
    // Specific file provided
    if (!existsSync(path)) {
      console.error(chalk.red(`File not found: ${path}`));
      process.exit(1);
    }
    files = [resolve(path)];
  } else {
    // No path provided, validate all existing settings files
    files = SETTINGS_LOCATIONS
      .map(loc => loc.path)
      .filter(path => existsSync(path));
  }
  
  if (files.length === 0) {
    console.error(chalk.red('No files found to validate'));
    process.exit(1);
  }
  
  console.log(chalk.cyan(`Validating ${files.length} file(s)...\n`));
  
  let hasErrors = false;
  let totalErrors = 0;
  let totalWarnings = 0;
  
  for (const file of files) {
    console.log(chalk.blue(`Validating ${basename(file)}...`));
    
    const result = await validator.validateSettingsFile(file);
    
    console.log(validator.formatResults(result, options.verbose));
    if (!result.valid || result.warnings.length > 0) {
      console.log();
    }
    
    if (!result.valid) {
      hasErrors = true;
    }
    
    totalErrors += result.errors.length;
    totalWarnings += result.warnings.length;
  }
  
  if (hasErrors) {
    process.exit(1);
  }
}