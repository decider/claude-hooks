/**
 * Claude Hooks Configuration - Universal Entry Point
 * Edit this file to control which hooks run - changes take effect immediately!
 * 
 * Note: This file uses .cjs extension for CommonJS compatibility with ES modules
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
  
  // PreWrite: Runs before writing files
  preWrite: [],
  
  // PostWrite: Runs after writing files  
  postWrite: []
};

// Advanced usage (optional):
// You can also use pattern matching for more control:
/*
module.exports = {
  preToolUse: {
    'Bash': {
      '^git\\s+commit': ['typescript-check', 'lint-check'],
      '^npm\\s+install': ['check-package-age']
    }
  },
  postToolUse: ['code-quality-validator'],
  stop: ['doc-compliance']
};
*/