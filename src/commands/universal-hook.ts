#!/usr/bin/env node

import { HookInput } from '../types/hook-types.js';
import { readStdin } from '../utils/stdin-reader.js';
import { executeHook, logHookEvent } from '../utils/hook-executor.js';
import { loadHookConfig, getEventConfig } from '../utils/config-loader.js';
import { collectHooks } from '../utils/pattern-matcher.js';
import { logToFile, debugLog } from '../utils/hook-logger.js';

async function processHooks(input: HookInput): Promise<void> {
  const eventType = input.hook_event_name;
  logHookEvent(`Event: ${eventType}`);
  logToFile(`Event type: ${eventType}`);
  
  const config = await loadHookConfig();
  if (!config) return;
  
  const eventConfig = getEventConfig(config, eventType);
  if (!eventConfig) return;
  
  const hooks = collectHooks(eventConfig, input, eventType);
  
  debugLog(`Matched ${hooks.length} hooks: ${hooks.join(', ')}`);
  
  for (const hook of hooks) {
    debugLog(`Executing hook: ${hook}`);
    await executeHook(hook, input);
  }
}

export async function universalHook(): Promise<void> {
  logToFile('UNIVERSAL-HOOK STARTED');
  logHookEvent(`Started at ${new Date().toISOString()}`);
  
  try {
    const inputStr = await readStdin();
    logToFile(`Input received: ${inputStr.substring(0, 200)}`);
    
    const input: HookInput = JSON.parse(inputStr);
    debugLog(`Input: ${JSON.stringify(input, null, 2)}`);
    
    await processHooks(input);
  } catch (error) {
    console.error(`Universal hook error: ${error}`);
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  universalHook().catch(console.error);
}