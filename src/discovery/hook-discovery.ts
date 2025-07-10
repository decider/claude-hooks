import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { HookTemplates, DiscoveredHook, HookConfigs } from '../types.js';
import { HookTemplateValidator } from '../validation/hook-template-validator.js';

const HOOK_TEMPLATE_PATHS = [
  '.claude/hooks.json',
  '.claude/hook-templates.json',
  'hooks/templates.json'
];

export function discoverHookTemplates(workingDir: string = process.cwd()): DiscoveredHook[] {
  const discovered: DiscoveredHook[] = [];
  const validator = new HookTemplateValidator();
  
  for (const templatePath of HOOK_TEMPLATE_PATHS) {
    const fullPath = join(workingDir, templatePath);
    
    if (existsSync(fullPath)) {
      try {
        const content = readFileSync(fullPath, 'utf-8');
        const templates = JSON.parse(content);
        
        // Validate templates
        const validation = validator.validateTemplates(templates);
        
        if (!validation.valid) {
          console.error(`Warning: Invalid hook templates in ${fullPath}:`);
          validation.errors.forEach(error => console.error(`  - ${error}`));
          continue;
        }
        
        if (validation.warnings.length > 0) {
          console.warn(`Warnings for hook templates in ${fullPath}:`);
          validation.warnings.forEach(warning => console.warn(`  - ${warning}`));
        }
        
        // Convert templates to discovered hooks
        const validTemplates = templates as HookTemplates;
        Object.entries(validTemplates).forEach(([name, template]) => {
          discovered.push({
            name,
            event: template.event,
            matcher: template.matcher,
            pattern: template.pattern,
            description: template.description,
            command: template.command,
            source: 'project',
            requiresApiKey: template.requiresApiKey
          });
        });
      } catch (err) {
        // Skip files with parse errors
        console.error(`Warning: Failed to parse hook templates from ${fullPath}: ${err}`);
      }
    }
  }
  
  return discovered;
}

export function mergeHooksWithDiscovered(
  availableHooks: HookConfigs,
  discoveredHooks: DiscoveredHook[]
): DiscoveredHook[] {
  const allHooks: DiscoveredHook[] = [];
  
  // Add built-in hooks
  Object.entries(availableHooks).forEach(([name, config]) => {
    allHooks.push({
      name,
      ...config,
      source: 'built-in'
    });
  });
  
  // Add discovered hooks (project hooks)
  // Filter out any that have the same name as built-in hooks
  discoveredHooks.forEach(hook => {
    if (!availableHooks[hook.name]) {
      allHooks.push(hook);
    }
  });
  
  return allHooks;
}