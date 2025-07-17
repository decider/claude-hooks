#!/usr/bin/env node
/**
 * Example Hook: Multi-Event Monitor
 * 
 * This hook monitors multiple events and logs activity.
 * It demonstrates how to:
 * - Handle multiple event types in one hook
 * - Access different data structures for each event
 * - Track session activity
 * - Use event-specific data fields
 */

const fs = require('fs');
const path = require('path');

// Track session stats
const stats = {
  toolUses: 0,
  filesWritten: 0,
  bashCommands: 0,
  errors: 0
};

// Read input from stdin
let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(inputData);
    
    console.log(`🪝 Event: ${input.hook_event_name}`);
    
    switch (input.hook_event_name) {
      case 'PreToolUse':
        handlePreToolUse(input);
        break;
        
      case 'PostToolUse':
        handlePostToolUse(input);
        break;
        
      case 'PreWrite':
        handlePreWrite(input);
        break;
        
      case 'PostWrite':
        handlePostWrite(input);
        break;
        
      case 'Stop':
        handleStop(input);
        break;
        
      case 'SubagentStop':
        handleSubagentStop(input);
        break;
        
      default:
        console.log(`   Unhandled event type: ${input.hook_event_name}`);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error in multi-event-monitor:', error.message);
    process.exit(0);
  }
});

function handlePreToolUse(input) {
  stats.toolUses++;
  console.log(`   Tool: ${input.tool_name}`);
  
  // Log tool-specific information
  switch (input.tool_name) {
    case 'Bash':
      stats.bashCommands++;
      console.log(`   Command: ${input.tool_input.command}`);
      break;
      
    case 'Write':
    case 'Edit':
      console.log(`   File: ${input.tool_input.file_path}`);
      console.log(`   Size: ${input.tool_input.content.length} chars`);
      break;
      
    case 'Read':
      console.log(`   File: ${input.tool_input.file_path}`);
      break;
      
    case 'Grep':
      console.log(`   Pattern: ${input.tool_input.pattern}`);
      console.log(`   Path: ${input.tool_input.path || '.'}`);
      break;
  }
}

function handlePostToolUse(input) {
  console.log(`   Tool: ${input.tool_name}`);
  
  // Check if tool succeeded
  if (input.tool_response) {
    if (input.tool_response.success === false || input.tool_response.error) {
      stats.errors++;
      console.log(`   ❌ Tool failed: ${input.tool_response.error || 'Unknown error'}`);
    } else {
      console.log(`   ✅ Tool succeeded`);
    }
  }
}

function handlePreWrite(input) {
  console.log(`   File: ${input.file_path}`);
  console.log(`   Size: ${input.content.length} chars`);
  
  // Check file extension
  const ext = path.extname(input.file_path);
  console.log(`   Type: ${ext || 'no extension'}`);
}

function handlePostWrite(input) {
  stats.filesWritten++;
  console.log(`   File: ${input.file_path}`);
  console.log(`   Success: ${input.success ? '✅' : '❌'}`);
}

function handleStop(input) {
  console.log('   📊 Session Summary:');
  console.log(`   - Session ID: ${input.session_id}`);
  console.log(`   - Tool uses: ${stats.toolUses}`);
  console.log(`   - Bash commands: ${stats.bashCommands}`);
  console.log(`   - Files written: ${stats.filesWritten}`);
  console.log(`   - Errors: ${stats.errors}`);
  console.log(`   - Stop hook active: ${input.stop_hook_active}`);
  
  // Save session stats to file (optional)
  const statsFile = `/tmp/claude-session-${input.session_id}.json`;
  fs.writeFileSync(statsFile, JSON.stringify({
    sessionId: input.session_id,
    timestamp: new Date().toISOString(),
    stats: stats
  }, null, 2));
  console.log(`   📝 Stats saved to: ${statsFile}`);
}

function handleSubagentStop(input) {
  console.log('   Subagent (Task) completed');
  console.log(`   Session ID: ${input.session_id}`);
}