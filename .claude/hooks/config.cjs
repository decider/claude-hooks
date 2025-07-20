/**
 * Claude Hooks Configuration - Entry Points System
 * Edit this file to control which hooks run - changes take effect immediately\!
 */

module.exports = {
  // Stop: Runs when Claude finishes a task
  stop: ["code-quality-validator"],
  
  // PostToolUse: Runs after Write/Edit/MultiEdit operations
  postToolUse: ["code-quality-validator"]
};
