// Hook execution utilities

import { spawn } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import { HookInput, HookOutput } from '../types/hook-types.js';

export function logHookEvent(message: string): void {
  console.error(`[UNIVERSAL-HOOK] ${message}`);
}

export function handleHookOutput(stdout: string, hookName: string): void {
  if (!stdout.trim()) return;
  
  try {
    const output: HookOutput = JSON.parse(stdout.trim());
    logHookEvent(`Hook output: ${JSON.stringify(output)}`);
    
    if (output.continue === false) {
      if (output.stopReason) {
        console.error(`Hook stopped execution: ${output.stopReason}`);
      }
      logHookEvent('Hook blocking execution - exiting with code 2');
      process.exit(2);
    }
    
    if (output.decision === 'block' && output.reason) {
      console.error(output.reason);
      logHookEvent('Hook blocking execution - exiting with code 2');
      process.exit(2);
    }
    
    if (!output.suppressOutput) {
      console.log(stdout);
    }
  } catch (e) {
    console.log(stdout);
    logHookEvent('Hook output not JSON, treating as regular output');
  }
}

export function handleHookExit(code: number | null, hookName: string): void {
  if (code === 0) {
    return;
  } else if (code === 2) {
    logHookEvent('Hook returned exit code 2 - blocking execution');
    process.exit(2);
  } else {
    logHookEvent(`Hook failed with exit code ${code}`);
    throw new Error(`Hook ${hookName} exited with code ${code}`);
  }
}

export async function executeHook(hookName: string, input: HookInput): Promise<void> {
  return new Promise((resolve, reject) => {
    const hookPath = path.join(process.cwd(), 'hooks', `${hookName}.sh`);
    
    logHookEvent(`Executing hook: ${hookName}`);
    logHookEvent(`Direct path: ${hookPath}`);
    
    if (!fs.existsSync(hookPath)) {
      logHookEvent(`Hook file not found: ${hookPath}`);
      resolve();
      return;
    }
    
    const child = spawn('bash', [hookPath], {
      stdio: ['pipe', 'pipe', 'inherit']
    });
    
    let stdout = '';
    
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    child.stdin.write(JSON.stringify(input));
    child.stdin.end();
    
    child.on('close', (code) => {
      logHookEvent(`Hook '${hookName}' completed with exit code: ${code}`);
      
      handleHookOutput(stdout, hookName);
      
      try {
        handleHookExit(code, hookName);
        resolve();
      } catch (error) {
        reject(error);
      }
    });
    
    child.on('error', (err) => {
      logHookEvent(`Hook execution error: ${err.message}`);
      reject(err);
    });
  });
}