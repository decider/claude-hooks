/**
 * Claude Hooks Configuration - Universal Entry Point
 * Edit this file to control which hooks run - changes take effect immediately!
 * 
 * Note: This file uses .cjs extension for CommonJS compatibility with ES modules
 * 
 * Hooks receive ALL event data via stdin, including:
 * - session_id, transcript_path, hook_event_name (all events)
 * - tool_name, tool_input (PreToolUse, PostToolUse)
 * - tool_response (PostToolUse only)
 * - file_path, content (PreWrite, PostWrite)
 * - stop_hook_active (Stop, SubagentStop)
 * - message (Notification)
 * 
 * Simple configuration format:
 * - Each event type maps to an array of hook names
 * - No restart needed - just save this file
 */

module.exports = {
  // PreToolUse: Runs before tools like Bash, Read, Write, etc.
  preToolUse: ['typescript-check', 'lint-check'],
  
  // PostToolUse: Runs after tools complete
  postToolUse: ['code-quality-validator'],
  
  // Stop: Runs when Claude finishes a task
  stop: ['doc-compliance', 'task-completion-notify'],
  
  // SubagentStop: Runs when a Task subagent finishes
  subagentStop: [],
  
  // PreWrite: Runs before writing files
  preWrite: [],
  
  // PostWrite: Runs after writing files  
  postWrite: [],
  
  // PreCompact: Runs before context compaction
  preCompact: [],
  
  // Notification: Runs for user notifications
  notification: []
};

// Advanced usage (optional):
// You can use pattern matching for more control:
/*
module.exports = {
  // Pattern matching for tool commands
  preToolUse: {
    'Bash': {
      '^git\\s+commit': ['typescript-check', 'lint-check'],
      '^npm\\s+install': ['check-package-age']
    }
  },
  
  // Pattern matching for file paths
  preWrite: {
    '\\.test\\.(js|ts)$': ['test-validator'],
    'package\\.json$': ['package-validator']
  },
  
  postToolUse: ['code-quality-validator'],
  stop: ['doc-compliance'],
  subagentStop: ['task-summary'],
  notification: ['desktop-notifier']
};
*/