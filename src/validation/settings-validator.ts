import {
  ValidationError,
  ValidationResult,
  HookSettingsValidation,
  VALID_EVENTS,
  VALID_TOOLS,
  VALID_LOG_LEVELS
} from './types.js';

export class SettingsValidator {
  private errors: ValidationError[] = [];
  private warnings: ValidationError[] = [];
  private hookCount: number = 0;

  validate(settings: any): ValidationResult {
    this.errors = [];
    this.warnings = [];
    this.hookCount = 0;

    // Validate root structure
    if (!settings || typeof settings !== 'object') {
      this.addError('', 'Settings must be a valid JSON object');
      return this.getResult();
    }

    // Validate hooks section (optional - valid to have no hooks)
    if (settings.hooks !== undefined) {
      if (typeof settings.hooks !== 'object') {
        this.addError('hooks', 'Field "hooks" must be an object');
      } else {
        this.validateHooksSection(settings.hooks);
      }
    }

    // Validate logging section if present
    if (settings.logging) {
      this.validateLoggingSection(settings.logging);
    }

    return this.getResult();
  }

  private validateHooksSection(hooks: any): void {
    for (const [event, groups] of Object.entries(hooks)) {
      // Validate event name
      if (!VALID_EVENTS.includes(event as any)) {
        this.addError(
          `hooks.${event}`,
          `Invalid event name "${event}"`,
          `Valid events are: ${VALID_EVENTS.join(', ')}`
        );
        continue;
      }

      // Validate groups array
      if (!Array.isArray(groups)) {
        this.addError(
          `hooks.${event}`,
          'Event configuration must be an array of hook groups'
        );
        continue;
      }

      // Validate each group
      groups.forEach((group, index) => {
        this.validateHookGroup(group, `hooks.${event}[${index}]`);
      });
    }
  }

  private validateHookGroup(group: any, path: string): void {
    if (!group || typeof group !== 'object') {
      this.addError(path, 'Hook group must be an object');
      return;
    }

    // Validate matcher
    if (group.matcher !== undefined) {
      if (typeof group.matcher !== 'string') {
        this.addError(`${path}.matcher`, 'Matcher must be a string');
      } else if (group.matcher.trim() === '') {
        this.addError(`${path}.matcher`, 'Matcher cannot be empty');
      } else {
        // Validate tool names in matcher
        const tools = group.matcher.split('|');
        for (const tool of tools) {
          if (!VALID_TOOLS.includes(tool.trim() as any)) {
            this.addWarning(
              `${path}.matcher`,
              `Unknown tool "${tool.trim()}" in matcher`,
              `Known tools: ${VALID_TOOLS.join(', ')}`
            );
          }
        }
      }
    }

    // Validate pattern
    if (group.pattern !== undefined) {
      if (typeof group.pattern !== 'string') {
        this.addError(`${path}.pattern`, 'Pattern must be a string');
      } else if (group.pattern.trim() === '') {
        this.addError(`${path}.pattern`, 'Pattern cannot be empty');
      } else {
        // Validate regex pattern
        try {
          new RegExp(group.pattern);
        } catch (e: any) {
          this.addError(
            `${path}.pattern`,
            `Invalid regex pattern: ${e.message}`
          );
        }
      }
    }

    // Validate hooks array
    if (!group.hooks) {
      this.addError(`${path}.hooks`, 'Missing required "hooks" array');
    } else if (!Array.isArray(group.hooks)) {
      this.addError(`${path}.hooks`, 'Hooks must be an array');
    } else {
      group.hooks.forEach((hook: any, index: number) => {
        this.validateHook(hook, `${path}.hooks[${index}]`);
      });
    }
  }

  private validateHook(hook: any, path: string): void {
    if (!hook || typeof hook !== 'object') {
      this.addError(path, 'Hook must be an object');
      return;
    }

    // Validate type
    if (!hook.type) {
      this.addError(`${path}.type`, 'Missing required "type" field');
    } else if (hook.type !== 'command') {
      this.addError(
        `${path}.type`,
        `Invalid hook type "${hook.type}"`,
        'Currently only "command" type is supported'
      );
    }

    // Validate command
    if (!hook.command) {
      this.addError(`${path}.command`, 'Missing required "command" field');
    } else if (typeof hook.command !== 'string') {
      this.addError(`${path}.command`, 'Command must be a string');
    } else if (hook.command.trim() === '') {
      this.addError(`${path}.command`, 'Command cannot be empty');
    } else {
      // Only count valid hooks
      this.hookCount++;
    }
  }

  private validateLoggingSection(logging: any): void {
    if (typeof logging !== 'object') {
      this.addError('logging', 'Logging configuration must be an object');
      return;
    }

    // Validate enabled
    if (logging.enabled !== undefined && typeof logging.enabled !== 'boolean') {
      this.addError('logging.enabled', 'Enabled must be a boolean');
    }

    // Validate level
    if (logging.level !== undefined) {
      if (typeof logging.level !== 'string') {
        this.addError('logging.level', 'Level must be a string');
      } else if (!VALID_LOG_LEVELS.includes(logging.level as any)) {
        this.addError(
          'logging.level',
          `Invalid log level "${logging.level}"`,
          `Valid levels are: ${VALID_LOG_LEVELS.join(', ')}`
        );
      }
    }

    // Validate path
    if (logging.path !== undefined && typeof logging.path !== 'string') {
      this.addError('logging.path', 'Path must be a string');
    }

    // Validate maxSize
    if (logging.maxSize !== undefined) {
      if (typeof logging.maxSize !== 'string') {
        this.addError('logging.maxSize', 'MaxSize must be a string');
      } else if (!/^\d+[KMG]?B?$/i.test(logging.maxSize)) {
        this.addError(
          'logging.maxSize',
          'Invalid maxSize format',
          'Use format like "10MB", "1GB", or "512KB"'
        );
      }
    }

    // Validate retention
    if (logging.retention !== undefined) {
      if (typeof logging.retention !== 'string') {
        this.addError('logging.retention', 'Retention must be a string');
      } else if (!/^\d+d$/i.test(logging.retention)) {
        this.addError(
          'logging.retention',
          'Invalid retention format',
          'Use format like "7d", "30d"'
        );
      }
    }
  }

  private addError(path: string, message: string, suggestion?: string): void {
    this.errors.push({
      path,
      message,
      severity: 'error',
      suggestion
    });
  }

  private addWarning(path: string, message: string, suggestion?: string): void {
    this.warnings.push({
      path,
      message,
      severity: 'warning',
      suggestion
    });
  }

  private getResult(): ValidationResult {
    return {
      valid: this.errors.length === 0,
      errors: this.errors,
      warnings: this.warnings,
      fixable: 0, // Will be implemented later
      hookCount: this.hookCount
    };
  }
}