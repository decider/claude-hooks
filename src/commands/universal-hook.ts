#!/usr/bin/env node

import { spawn } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

// Common fields for all hook events
interface BaseHookInput {
  session_id: string;
  transcript_path: string;
  hook_event_name: string;
}

// PreToolUse event
interface PreToolUseInput extends BaseHookInput {
  hook_event_name: 'PreToolUse';
  tool_name: string;
  tool_input: {
    command?: string;
    file_path?: string;
    content?: string;
    pattern?: string;
    [key: string]: any;
  };
}

// PostToolUse event
interface PostToolUseInput extends BaseHookInput {
  hook_event_name: 'PostToolUse';
  tool_name: string;
  tool_input: {
    command?: string;
    file_path?: string;
    content?: string;
    pattern?: string;
    [key: string]: any;
  };
  tool_response: {
    success?: boolean;
    filePath?: string;
    error?: string;
    [key: string]: any;
  };
}

// Stop event
interface StopInput extends BaseHookInput {
  hook_event_name: 'Stop';
  stop_hook_active: boolean;
}

// SubagentStop event
interface SubagentStopInput extends BaseHookInput {
  hook_event_name: 'SubagentStop';
  stop_hook_active: boolean;
}

// PreCompact event
interface PreCompactInput extends BaseHookInput {
  hook_event_name: 'PreCompact';
  trigger: 'manual' | 'auto';
  custom_instructions: string;
}

// PreWrite event
interface PreWriteInput extends BaseHookInput {
  hook_event_name: 'PreWrite';
  file_path: string;
  content: string;
}

// PostWrite event
interface PostWriteInput extends BaseHookInput {
  hook_event_name: 'PostWrite';
  file_path: string;
  content: string;
  success: boolean;
}

// Notification event
interface NotificationInput extends BaseHookInput {
  hook_event_name: 'Notification';
  message: string;
}

type HookInput = PreToolUseInput | PostToolUseInput | StopInput | SubagentStopInput | 
                 PreCompactInput | PreWriteInput | PostWriteInput | NotificationInput;

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  
  return new Promise((resolve, reject) => {
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolve(Buffer.concat(chunks).toString()));
    process.stdin.on('error', reject);
  });
}

async function executeHook(hookName: string, input: HookInput): Promise<void> {
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
    const input: HookInput = JSON.parse(inputStr);
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
      // Type guard to ensure we have tool_name
      if ('tool_name' in input) {
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
    }
    
    // For write events, check for file path pattern matching
    if ((eventType === 'PreWrite' || eventType === 'PostWrite') && !Array.isArray(eventConfig)) {
      // Type guard to ensure we have file_path
      if ('file_path' in input) {
        for (const [pattern, hookList] of Object.entries(eventConfig)) {
          if (new RegExp(pattern).test(input.file_path)) {
            hooks.push(...(hookList as string[]));
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