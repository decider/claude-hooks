#!/usr/bin/env node

import { HookEntryPoint } from './base.js';
import { logger } from '../testing/logger.js';

async function main(options?: { matcher?: string }) {
  const entryPoint = new HookEntryPoint('PreToolUse');
  
  try {
    // Read input from Claude
    const input = await entryPoint.readInput();
    
    // If we have a matcher from settings.json, only process matching tools
    if (options?.matcher && !entryPoint.matchesTool(input.tool_name, options.matcher)) {
      logger.debug('PreToolUse', `Tool ${input.tool_name} doesn't match filter ${options.matcher}, skipping`);
      return;
    }
    
    // Load config (fresh each time)
    const config = await entryPoint.loadConfig();
    
    if (!config.preToolUse) {
      logger.debug('PreToolUse', 'No PreToolUse hooks configured');
      return;
    }
    
    // Check each matcher/pattern combination
    for (const [matcher, patterns] of Object.entries(config.preToolUse)) {
      if (!entryPoint.matchesTool(input.tool_name, matcher)) {
        continue;
      }
      
      // Check each pattern for this matcher
      for (const [pattern, hooks] of Object.entries(patterns)) {
        let shouldRun = false;
        
        // Check pattern against relevant field based on tool
        if (input.tool_name === 'Bash' && input.tool_input.command) {
          shouldRun = entryPoint.matchesPattern(input.tool_input.command, pattern);
        } else if (pattern === '*') {
          // Wildcard pattern always matches
          shouldRun = true;
        }
        
        if (shouldRun) {
          // Execute all hooks for this pattern
          for (const hookName of hooks) {
            logger.info('PreToolUse', `Running hook: ${hookName}`);
            await entryPoint.executeHook(hookName, input);
          }
        }
      }
    }
  } catch (error: any) {
    logger.error('PreToolUse', `Entry point error: ${error.message}`);
    process.exit(1);
  }
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}

export { main };