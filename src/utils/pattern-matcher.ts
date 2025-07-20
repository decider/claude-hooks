// Pattern matching utilities for hooks

import { HookInput } from '../types/hook-types.js';

export function matchToolPatterns(
  eventConfig: any,
  input: HookInput,
  eventType: string
): string[] {
  const hooks: string[] = [];
  
  if (!('tool_name' in input)) return hooks;
  
  const toolConfig = eventConfig[input.tool_name];
  if (!toolConfig) return hooks;
  
  if (Array.isArray(toolConfig)) {
    return toolConfig;
  }
  
  const isFileOperation = ['Write', 'Edit', 'MultiEdit'].includes(input.tool_name);
  const targetValue = isFileOperation 
    ? input.tool_input?.file_path || ''
    : input.tool_input?.command || '';
  
  for (const [pattern, hookList] of Object.entries(toolConfig)) {
    if (new RegExp(pattern).test(targetValue)) {
      hooks.push(...(hookList as string[]));
    }
  }
  
  return hooks;
}

export function matchFilePatterns(eventConfig: any, filePath: string): string[] {
  const hooks: string[] = [];
  
  for (const [pattern, hookList] of Object.entries(eventConfig)) {
    if (new RegExp(pattern).test(filePath)) {
      hooks.push(...(hookList as string[]));
    }
  }
  
  return hooks;
}

export function collectHooks(
  eventConfig: any,
  input: HookInput,
  eventType: string
): string[] {
  if (Array.isArray(eventConfig)) {
    return eventConfig;
  }
  
  const hooks: string[] = [];
  
  if ((eventType === 'PreToolUse' || eventType === 'PostToolUse')) {
    hooks.push(...matchToolPatterns(eventConfig, input, eventType));
  }
  
  return hooks;
}