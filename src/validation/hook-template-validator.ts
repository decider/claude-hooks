import { HookTemplates, HookTemplate } from '../types.js';

export interface TemplateValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

export class HookTemplateValidator {
  private validEvents = ['PreToolUse', 'PostToolUse', 'Stop'];
  
  validateTemplates(templates: unknown): TemplateValidationResult {
    const result: TemplateValidationResult = {
      valid: true,
      errors: [],
      warnings: []
    };
    
    // Check if templates is an object
    if (typeof templates !== 'object' || templates === null || Array.isArray(templates)) {
      result.valid = false;
      result.errors.push('Hook templates must be an object');
      return result;
    }
    
    const templatesObj = templates as Record<string, unknown>;
    
    // Validate each template
    Object.entries(templatesObj).forEach(([name, template]) => {
      this.validateTemplate(name, template, result);
    });
    
    return result;
  }
  
  private validateTemplate(name: string, template: unknown, result: TemplateValidationResult): void {
    // Check if template is an object
    if (typeof template !== 'object' || template === null || Array.isArray(template)) {
      result.valid = false;
      result.errors.push(`Template '${name}' must be an object`);
      return;
    }
    
    const templateObj = template as Record<string, unknown>;
    
    // Check required fields
    if (!templateObj.event) {
      result.valid = false;
      result.errors.push(`Template '${name}' missing required field 'event'`);
    } else if (!this.validEvents.includes(templateObj.event as string)) {
      result.valid = false;
      result.errors.push(`Template '${name}' has invalid event '${templateObj.event}'. Valid events: ${this.validEvents.join(', ')}`);
    }
    
    if (!templateObj.description) {
      result.valid = false;
      result.errors.push(`Template '${name}' missing required field 'description'`);
    }
    
    // Check optional fields
    if (templateObj.matcher && typeof templateObj.matcher !== 'string') {
      result.valid = false;
      result.errors.push(`Template '${name}' field 'matcher' must be a string`);
    }
    
    if (templateObj.pattern && typeof templateObj.pattern !== 'string') {
      result.valid = false;
      result.errors.push(`Template '${name}' field 'pattern' must be a string`);
    }
    
    if (templateObj.command && typeof templateObj.command !== 'string') {
      result.valid = false;
      result.errors.push(`Template '${name}' field 'command' must be a string`);
    }
    
    // Validate regex pattern if provided
    if (templateObj.pattern && typeof templateObj.pattern === 'string') {
      try {
        new RegExp(templateObj.pattern);
      } catch (e) {
        result.valid = false;
        result.errors.push(`Template '${name}' has invalid regex pattern: ${e}`);
      }
    }
    
    // Warnings
    if (!templateObj.command) {
      result.warnings.push(`Template '${name}' has no custom command - will use default exec pattern`);
    }
    
    if (name.length > 50) {
      result.warnings.push(`Template '${name}' has a very long name (${name.length} chars) - consider shortening`);
    }
  }
}