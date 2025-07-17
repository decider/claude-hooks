/**
 * Claude Hooks Configuration - Entry Points System
 * Edit this file to control which hooks run - changes take effect immediately!
 * 
 * Note: This file uses .cjs extension for CommonJS compatibility with ES modules
 * 
 * Configuration format for Entry Points system:
 * - Simple arrays: ['hook1', 'hook2'] 
 * - Pattern matching: { 'Tool': { 'pattern': ['hooks'] } }
 * - File patterns: { 'pattern': ['hooks'] } for Write events
 */

module.exports = {
  // PreToolUse: Runs before tools like Bash, Read, Write, etc.
  preToolUse: {
    'Bash': {
      '^(npm\\s+(install|i|add)|yarn\\s+(add|install))\\s+': ['check-package-age'],
      '^git\\s+commit': ['typescript-check', 'lint-check']
    }
  },
  
  // PostToolUse: Runs after tools complete
  postToolUse: {
    'Write|Edit|MultiEdit': ['code-quality-validator']
  },
  
  // Stop: Runs when Claude finishes a task
  stop: ['doc-compliance'],
  
  // PreWrite: Runs before writing files
  preWrite: {
    '\\.test-trigger$': ['self-test']
  },
  
  // PostWrite: Runs after writing files  
  postWrite: {}
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