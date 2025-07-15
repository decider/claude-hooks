#!/usr/bin/env node

import { HookEntryPoint } from './base.js';
import { logger } from '../testing/logger.js';

async function main() {
  const entryPoint = new HookEntryPoint('PostToolUse');
  
  try {
    // Read input from Claude
    const input = await entryPoint.readInput();
    
    // Load config (fresh each time)
    const config = await entryPoint.loadConfig();
    
    if (!config.postToolUse) {
      logger.debug('PostToolUse', 'No PostToolUse hooks configured');
      return;
    }
    
    // Check each matcher
    for (const [matcher, hooks] of Object.entries(config.postToolUse)) {
      if (!entryPoint.matchesTool(input.tool_name, matcher)) {
        continue;
      }
      
      // Execute all hooks for this matcher
      for (const hookName of hooks) {
        logger.info('PostToolUse', `Running hook: ${hookName}`);
        await entryPoint.executeHook(hookName, input);
      }
    }
  } catch (error: any) {
    logger.error('PostToolUse', `Entry point error: ${error.message}`);
    process.exit(1);
  }
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}

export { main };