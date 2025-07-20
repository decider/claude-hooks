// Hook logging utilities

import * as fs from 'fs';
import * as path from 'path';

export function logToFile(message: string): void {
  const logFile = path.join(process.cwd(), '.claude', 'hooks', 'execution.log');
  const timestamp = new Date().toISOString();
  
  try {
    fs.appendFileSync(logFile, `[${timestamp}] ${message}\n`);
  } catch (e) {
    // Ignore logging errors
  }
}

export function debugLog(message: string): void {
  if (process.env.HOOK_DEBUG) {
    console.error(`[HOOK DEBUG] ${message}`);
  }
}