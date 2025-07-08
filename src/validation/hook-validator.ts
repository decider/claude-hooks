import fs from 'fs/promises';
import path from 'path';
import { ValidationResult, ValidationError } from './types.js';
import { SettingsValidator } from './settings-validator.js';

export class HookValidator {
  private settingsValidator: SettingsValidator;

  constructor() {
    this.settingsValidator = new SettingsValidator();
  }

  /**
   * Validate a settings file
   */
  async validateSettingsFile(filePath: string): Promise<ValidationResult> {
    try {
      // Read the file
      const content = await fs.readFile(filePath, 'utf-8');
      
      // Parse JSON
      let settings: any;
      try {
        settings = JSON.parse(content);
      } catch (e: any) {
        return {
          valid: false,
          errors: [{
            path: '',
            message: `Invalid JSON: ${e.message}`,
            severity: 'error'
          }],
          warnings: [],
          fixable: 0
        };
      }

      // Validate settings structure
      const result = this.settingsValidator.validate(settings);
      
      // Add file context to errors
      result.errors = result.errors.map(error => ({
        ...error,
        message: `${path.basename(filePath)}: ${error.message}`
      }));
      
      result.warnings = result.warnings.map(warning => ({
        ...warning,
        message: `${path.basename(filePath)}: ${warning.message}`
      }));

      return result;
    } catch (e: any) {
      return {
        valid: false,
        errors: [{
          path: '',
          message: `Failed to read file: ${e.message}`,
          severity: 'error'
        }],
        warnings: [],
        fixable: 0
      };
    }
  }

  /**
   * Validate settings object (for runtime validation)
   */
  validateSettings(settings: any): ValidationResult {
    return this.settingsValidator.validate(settings);
  }

  /**
   * Format validation results for display
   */
  formatResults(result: ValidationResult, verbose = false): string {
    const lines: string[] = [];

    if (result.valid) {
      const hookCount = result.hookCount ?? 0;
      const hookText = hookCount === 1 ? 'hook' : 'hooks';
      lines.push(`✅ Valid (${hookCount} ${hookText})`);
    } else {
      lines.push('❌ Invalid');
    }

    if (result.errors.length > 0) {
      lines.push('\nErrors:');
      result.errors.forEach(error => {
        lines.push(`  - ${error.path ? `[${error.path}] ` : ''}${error.message}`);
        if (error.suggestion && verbose) {
          lines.push(`    💡 ${error.suggestion}`);
        }
      });
    }

    if (result.warnings.length > 0) {
      lines.push('\nWarnings:');
      result.warnings.forEach(warning => {
        lines.push(`  - ${warning.path ? `[${warning.path}] ` : ''}${warning.message}`);
        if (warning.suggestion && verbose) {
          lines.push(`    💡 ${warning.suggestion}`);
        }
      });
    }

    if (result.fixable > 0) {
      lines.push(`\n${result.fixable} issue(s) can be automatically fixed with --fix`);
    }

    return lines.join('\n');
  }
}