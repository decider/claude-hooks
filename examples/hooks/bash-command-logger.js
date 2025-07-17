#!/usr/bin/env node
/**
 * Example Hook: Bash Command Logger
 * 
 * This hook logs all Bash commands executed by Claude to a file.
 * It demonstrates how to:
 * - Read event data from stdin
 * - Filter for specific events (PreToolUse with Bash)
 * - Extract command information
 * - Log to a file with timestamps
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Configuration
const LOG_FILE = path.join(os.homedir(), '.claude', 'bash-history.log');

// Ensure log directory exists
const logDir = path.dirname(LOG_FILE);
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// Read input from stdin
let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(inputData);
    
    // Only process PreToolUse events for Bash
    if (input.hook_event_name !== 'PreToolUse' || input.tool_name !== 'Bash') {
      process.exit(0);
    }
    
    // Extract command
    const command = input.tool_input.command;
    const timestamp = new Date().toISOString();
    const sessionId = input.session_id;
    
    // Create log entry
    const logEntry = `[${timestamp}] [${sessionId}] ${command}\n`;
    
    // Append to log file
    fs.appendFileSync(LOG_FILE, logEntry);
    
    // Also log to console
    console.log(`📝 Logged command: ${command}`);
    
    // Check for potentially dangerous commands
    if (command.includes('rm -rf') && !command.includes('node_modules')) {
      console.warn('⚠️  Warning: Potentially dangerous rm command detected!');
    }
    
    // Always exit successfully (we don't want to block commands)
    process.exit(0);
  } catch (error) {
    console.error('❌ Error in bash-command-logger:', error.message);
    // Exit successfully even on error (don't block Claude)
    process.exit(0);
  }
});