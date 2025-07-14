#!/usr/bin/env node

import { HookEntryPoint } from './base.js';
import { logger } from '../testing/logger.js';

async function main() {
  const entryPoint = new HookEntryPoint('Stop');
  
  try {
    // Read input from Claude
    const input = await entryPoint.readInput();
    
    // Load config (fresh each time)
    const config = await entryPoint.loadConfig();
    
    if (!config.stop || config.stop.length === 0) {
      logger.debug('Stop', 'No Stop hooks configured');
      return;
    }
    
    // Execute all stop hooks
    for (const hookName of config.stop) {
      logger.info('Stop', `Running hook: ${hookName}`);
      await entryPoint.executeHook(hookName, input);
    }
  } catch (error: any) {
    logger.error('Stop', `Entry point error: ${error.message}`);
    process.exit(1);
  }
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}

export { main };