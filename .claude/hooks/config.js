/**
 * Claude Hooks Configuration
 * Edit this file to control which hooks run - changes take effect immediately!
 */

module.exports = {
  // PreToolUse: Runs before tools like Bash, Read, Write, etc.
  preToolUse: {
    'Bash': {
      '^(npm\\s+(install|i|add)|yarn\\s+(add|install))\\s+': ['check-package-age'],
    }
  },
  
  // PostToolUse: Runs after tools complete
  postToolUse: {
    'Write|Edit|MultiEdit': ['code-quality-validator'],
  },
  
  // Stop: Runs when Claude finishes a task
  stop: ['doc-compliance'],
  
  // PreWrite: Runs before writing files
  preWrite: {
    '\\.test-trigger$': ['self-test'],
  },
  
  // PostWrite: Runs after writing files  
  postWrite: {}
};