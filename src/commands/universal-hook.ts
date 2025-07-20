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

// UserPromptSubmit event
interface UserPromptSubmitInput extends BaseHookInput {
  hook_event_name: 'UserPromptSubmit';
  prompt: string;
}

type HookInput = PreToolUseInput | PostToolUseInput | StopInput | SubagentStopInput | 
                 PreCompactInput | PreWriteInput | PostWriteInput | NotificationInput |
                 UserPromptSubmitInput;

// Hook output JSON structure
interface HookOutput {
  continue?: boolean;
  stopReason?: string;
  decision?: 'approve' | 'block';
  reason?: string;
  suppressOutput?: boolean;
}

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
    // Direct hook execution - find and run the script directly
    const hookPath = path.join(process.cwd(), 'hooks', `${hookName}.sh`);
    
    console.error(`[UNIVERSAL-HOOK] Executing hook: ${hookName}`);
    console.error(`[UNIVERSAL-HOOK] Direct path: ${hookPath}`);
    
    // Check if hook file exists
    if (!fs.existsSync(hookPath)) {
      console.error(`[UNIVERSAL-HOOK] Hook file not found: ${hookPath}`);
      resolve(); // Don't fail if hook doesn't exist
      return;
    }
    
    const child = spawn('bash', [hookPath], {
      stdio: ['pipe', 'pipe', 'inherit']  // Capture stdout
    });
    
    let stdout = '';
    
    // Capture stdout
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    child.stdin.write(JSON.stringify(input));
    child.stdin.end();
    
    child.on('close', (code) => {
      console.error(`[UNIVERSAL-HOOK] Hook '${hookName}' completed with exit code: ${code}`);
      
      // Try to parse stdout as JSON for hook output
      if (stdout.trim()) {
        try {
          const output: HookOutput = JSON.parse(stdout.trim());
          
          console.error(`[UNIVERSAL-HOOK] Hook output: ${JSON.stringify(output)}`);
          
          // Handle continue: false
          if (output.continue === false) {
            // Output stopReason to stderr for Claude to see
            if (output.stopReason) {
              console.error(`Hook stopped execution: ${output.stopReason}`);
            }
            // Exit with code 2 to indicate blocking
            console.error(`[UNIVERSAL-HOOK] Hook blocking execution - exiting with code 2`);
            process.exit(2);
          }
          
          // Handle decision: block for appropriate events
          if (output.decision === 'block' && output.reason) {
            console.error(output.reason);
            console.error(`[UNIVERSAL-HOOK] Hook blocking execution - exiting with code 2`);
            process.exit(2);
          }
          
          // If suppressOutput is not true, write stdout to console
          if (!output.suppressOutput) {
            console.log(stdout);
          }
        } catch (e) {
          // Not JSON, treat as regular output
          console.log(stdout);
          console.error(`[UNIVERSAL-HOOK] Hook output not JSON, treating as regular output`);
        }
      }
      
      if (code === 0) {
        resolve();
      } else if (code === 2) {
        // Exit code 2 is blocking, propagate it
        console.error(`[UNIVERSAL-HOOK] Hook returned exit code 2 - blocking execution`);
        process.exit(2);
      } else {
        console.error(`[UNIVERSAL-HOOK] Hook failed with exit code ${code}`);
        reject(new Error(`Hook ${hookName} exited with code ${code}`));
      }
    });
    
    child.on('error', (err) => {
      console.error(`[UNIVERSAL-HOOK] Hook execution error: ${err.message}`);
      reject(err);
    });
  });
}

export async function universalHook(): Promise<void> {
  // ALWAYS log to prove we're running
  const logFile = path.join(process.cwd(), '.claude', 'hooks', 'execution.log');
  const timestamp = new Date().toISOString();
  try {
    fs.appendFileSync(logFile, `\n[${timestamp}] UNIVERSAL-HOOK STARTED\n`);
  } catch (e) {
    // Ignore logging errors
  }
  
  // Also log to stderr so we can see it
  console.error(`[UNIVERSAL-HOOK] Started at ${timestamp}`);
  
  try {
    // Read input from Claude
    const inputStr = await readStdin();
    try {
      fs.appendFileSync(logFile, `[${timestamp}] Input received: ${inputStr.substring(0, 200)}\n`);
    } catch (e) {
      // Ignore
    }
    
    const input: HookInput = JSON.parse(inputStr);
    const eventType = input.hook_event_name;
    
    // ALWAYS log the event type
    console.error(`[UNIVERSAL-HOOK] Event: ${eventType}`);
    try {
      fs.appendFileSync(logFile, `[${timestamp}] Event type: ${eventType}\n`);
    } catch (e) {
      // Ignore
    }
    
    // Debug logging
    if (process.env.HOOK_DEBUG) {
      console.error(`[HOOK DEBUG] Event: ${eventType}`);
      console.error(`[HOOK DEBUG] Input: ${JSON.stringify(input, null, 2)}`);
    }
    
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
    const configKey = eventType ? eventType.charAt(0).toLowerCase() + eventType.slice(1) : '';
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
            // Pattern matching for tool input
            if (input.tool_name === 'Write' || input.tool_name === 'Edit' || input.tool_name === 'MultiEdit') {
              // For file operations, match against file_path
              const filePath = input.tool_input?.file_path || '';
              for (const [pattern, hookList] of Object.entries(toolConfig)) {
                if (new RegExp(pattern).test(filePath)) {
                  hooks.push(...(hookList as string[]));
                }
              }
            } else {
              // For other tools like Bash, match against command
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
    if (process.env.HOOK_DEBUG) {
      console.error(`[HOOK DEBUG] Matched ${hooks.length} hooks: ${hooks.join(', ')}`);
    }
    
    for (const hook of hooks) {
      if (process.env.HOOK_DEBUG) {
        console.error(`[HOOK DEBUG] Executing hook: ${hook}`);
      }
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