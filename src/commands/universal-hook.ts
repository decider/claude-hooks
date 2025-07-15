#!/usr/bin/env node

import { spawn } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  
  return new Promise((resolve, reject) => {
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolve(Buffer.concat(chunks).toString()));
    process.stdin.on('error', reject);
  });
}

async function executeHook(hookName: string, input: any): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn('npx', ['claude-code-hooks-cli', 'exec', hookName], {
      stdio: ['pipe', 'inherit', 'inherit']
    });
    
    child.stdin.write(JSON.stringify(input));
    child.stdin.end();
    
    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Hook ${hookName} exited with code ${code}`));
      }
    });
  });
}

export async function universalHook(): Promise<void> {
  try {
    // Read input from Claude
    const inputStr = await readStdin();
    const input = JSON.parse(inputStr);
    const eventType = input.hook_event_name;
    
    // Determine config path - try .cjs first, then .js
    let configPath = path.join(process.cwd(), '.claude', 'hooks', 'config.cjs');
    if (!fs.existsSync(configPath)) {
      configPath = path.join(process.cwd(), '.claude', 'hooks', 'config.js');
      if (!fs.existsSync(configPath)) {
        // No config, nothing to do
        return;
      }
    }
    
    // Load config (always fresh) using dynamic import
    const configUrl = new URL(`file://${configPath}`).href;
    const config = await import(`${configUrl}?t=${Date.now()}`).then(m => m.default || m);
    
    // Convert event name from PascalCase to camelCase for config lookup
    const configKey = eventType.charAt(0).toLowerCase() + eventType.slice(1);
    const eventConfig = config[configKey];
    if (!eventConfig) {
      return;
    }
    
    // Execute hooks based on event type
    const hooks = Array.isArray(eventConfig) ? eventConfig : [];
    
    // For tool events, check if we need pattern matching
    if ((eventType === 'PreToolUse' || eventType === 'PostToolUse') && !Array.isArray(eventConfig)) {
      const toolConfig = eventConfig[input.tool_name];
      if (toolConfig) {
        if (Array.isArray(toolConfig)) {
          hooks.push(...toolConfig);
        } else {
          // Pattern matching for commands
          const command = input.tool_input?.command || '';
          for (const [pattern, hookList] of Object.entries(toolConfig)) {
            if (new RegExp(pattern).test(command)) {
              hooks.push(...(hookList as string[]));
            }
          }
        }
      }
    }
    
    // Execute all matched hooks
    for (const hook of hooks) {
      await executeHook(hook, input);
    }
  } catch (error) {
    console.error(`Universal hook error: ${error}`);
    process.exit(1);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  universalHook().catch(console.error);
}