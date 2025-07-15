#!/usr/bin/env node

import { HookEntryPoint } from './base.js';
import { logger } from '../testing/logger.js';

async function main() {
  const entryPoint = new HookEntryPoint('PostWrite');
  
  try {
    // Read input from Claude
    const input = await entryPoint.readInput();
    
    // Load config (fresh each time)
    const config = await entryPoint.loadConfig();
    
    if (!config.postWrite) {
      logger.debug('PostWrite', 'No PostWrite hooks configured');
      return;
    }
    
    // Get the file path from Write tool input
    const filePath = input.tool_input?.file_path || '';
    
    // Check each pattern
    for (const [pattern, hooks] of Object.entries(config.postWrite)) {
      if (entryPoint.matchesPattern(filePath, pattern)) {
        // Execute all hooks for this pattern
        for (const hookName of hooks) {
          logger.info('PostWrite', `Running hook: ${hookName} for file: ${filePath}`);
          await entryPoint.executeHook(hookName, input);
        }
      }
    }
  } catch (error: any) {
    logger.error('PostWrite', `Entry point error: ${error.message}`);
    process.exit(1);
  }
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}

export { main };