# Hook Development Guide

This guide explains how to write custom hooks for Claude Code that can respond to different events and access all the context they need.

## Table of Contents

- [Understanding Hook Events](#understanding-hook-events)
- [Accessing Event Data](#accessing-event-data)
- [Writing Your First Hook](#writing-your-first-hook)
- [Event-Specific Examples](#event-specific-examples)
- [Testing Your Hooks](#testing-your-hooks)
- [Best Practices](#best-practices)

## Understanding Hook Events

Claude Code triggers hooks at specific points during its operation:

- **PreToolUse** - Before executing any tool (Bash, Write, Edit, etc.)
- **PostToolUse** - After a tool completes execution
- **Stop** - When Claude finishes responding
- **SubagentStop** - When a Task subagent finishes
- **PreWrite** - Before writing a file
- **PostWrite** - After writing a file
- **PreCompact** - Before context compaction
- **Notification** - For user notifications

## Accessing Event Data

### How Hooks Receive Data

Every hook receives complete event context via **stdin as JSON**. This includes:
- The event type
- Session information
- Tool-specific data
- File paths and content
- Success/failure status

### Reading Input in Your Hook

Here's how to read the JSON input in different languages:

**Bash:**
```bash
#!/bin/bash
# Read all stdin into a variable
INPUT=$(cat)

# Extract specific fields using jq
EVENT_TYPE=$(echo "$INPUT" | jq -r '.hook_event_name')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
```

**Node.js:**
```javascript
#!/usr/bin/env node
let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  const input = JSON.parse(inputData);
  console.log(`Event: ${input.hook_event_name}`);
});
```

**Python:**
```python
#!/usr/bin/env python3
import sys
import json

input_data = json.load(sys.stdin)
event_type = input_data['hook_event_name']
print(f"Event: {event_type}")
```

## Writing Your First Hook

### Basic Hook Template

```javascript
#!/usr/bin/env node

// Read stdin
let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  const input = JSON.parse(inputData);
  
  // Log what triggered us
  console.log(`🪝 Hook triggered by: ${input.hook_event_name}`);
  
  // Handle different events
  switch (input.hook_event_name) {
    case 'PreToolUse':
      handlePreToolUse(input);
      break;
    case 'Stop':
      handleStop(input);
      break;
    // ... other events
  }
});

function handlePreToolUse(input) {
  console.log(`Tool: ${input.tool_name}`);
  
  // Example: Check for npm install
  if (input.tool_name === 'Bash' && 
      input.tool_input.command.includes('npm install')) {
    console.log('⚠️  Installing npm packages!');
  }
}

function handleStop(input) {
  console.log('✅ Claude finished responding');
}
```

## Event-Specific Examples

### PreToolUse Event

Triggered before any tool executes. Perfect for validation and checks.

**Data Structure:**
```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m 'feat: add new feature'"
  }
}
```

**Example: Git Commit Checker**
```javascript
#!/usr/bin/env node
const { execSync } = require('child_process');

// Read input
let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  const input = JSON.parse(inputData);
  
  // Only check git commits
  if (input.tool_name !== 'Bash' || 
      !input.tool_input.command.match(/^git\s+commit/)) {
    process.exit(0);
  }
  
  console.log('🔍 Running pre-commit checks...');
  
  try {
    // Run TypeScript check
    execSync('npm run typecheck', { stdio: 'inherit' });
    console.log('✅ TypeScript check passed');
  } catch (error) {
    console.error('❌ TypeScript errors found');
    process.exit(1);
  }
});
```

### PostToolUse Event

Triggered after a tool completes. Includes the tool's response.

**Data Structure:**
```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/src/index.js",
    "content": "console.log('Hello');"
  },
  "tool_response": {
    "success": true,
    "filePath": "/src/index.js"
  }
}
```

**Example: Code Quality Validator**
```javascript
#!/usr/bin/env node

let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  const input = JSON.parse(inputData);
  
  // Only validate file writes
  if (!['Write', 'Edit', 'MultiEdit'].includes(input.tool_name)) {
    process.exit(0);
  }
  
  const filePath = input.tool_input.file_path;
  const content = input.tool_input.content;
  
  // Check for console.log in production code
  if (!filePath.includes('.test.') && content.includes('console.log')) {
    console.warn('⚠️  Warning: console.log found in production code');
  }
  
  // Check file size
  if (content.length > 10000) {
    console.warn(`⚠️  Warning: Large file (${content.length} chars)`);
  }
});
```

### Stop Event

Triggered when Claude finishes responding.

**Data Structure:**
```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "hook_event_name": "Stop",
  "stop_hook_active": true
}
```

**Example: Task Summary**
```javascript
#!/usr/bin/env node
const fs = require('fs');

let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  const input = JSON.parse(inputData);
  
  if (input.hook_event_name !== 'Stop') return;
  
  console.log('📋 Session Summary:');
  console.log(`Session ID: ${input.session_id}`);
  
  // Read transcript to count actions
  if (fs.existsSync(input.transcript_path)) {
    const transcript = fs.readFileSync(input.transcript_path, 'utf-8')
      .split('\n')
      .filter(line => line.trim())
      .map(line => JSON.parse(line));
    
    const toolUses = transcript.filter(entry => 
      entry.type === 'tool_use'
    ).length;
    
    console.log(`Total tool uses: ${toolUses}`);
  }
});
```

### PreWrite/PostWrite Events

For file-specific operations.

**Data Structure:**
```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "hook_event_name": "PreWrite",
  "file_path": "/src/components/Button.tsx",
  "content": "export const Button = () => {...}"
}
```

**Example: File Extension Validator**
```javascript
#!/usr/bin/env node

let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  const input = JSON.parse(inputData);
  
  if (input.hook_event_name !== 'PreWrite') return;
  
  const filePath = input.file_path;
  const ext = filePath.split('.').pop();
  
  // Check for TypeScript in .js files
  if (ext === 'js' && input.content.includes(': string')) {
    console.error('❌ TypeScript syntax found in .js file!');
    console.error('Use .ts extension for TypeScript files');
    process.exit(1);
  }
  
  // Warn about large files
  if (input.content.length > 5000) {
    console.warn(`⚠️  Large file: ${filePath} (${input.content.length} chars)`);
  }
});
```

## Testing Your Hooks

### Manual Testing

Test your hooks by simulating Claude's input:

```bash
# Test PreToolUse event
echo '{
  "session_id": "test-123",
  "transcript_path": "/tmp/test.jsonl",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {"command": "npm install express"}
}' | ./my-hook.js

# Test Stop event
echo '{
  "session_id": "test-123",
  "transcript_path": "/tmp/test.jsonl",
  "hook_event_name": "Stop",
  "stop_hook_active": true
}' | ./my-hook.js
```

### Debugging Tips

1. **Log the input** to see what data you're receiving:
   ```javascript
   console.error('Input:', JSON.stringify(input, null, 2));
   ```

2. **Use stderr for debugging** (stdout might be captured):
   ```javascript
   console.error('Debug: Event type is', input.hook_event_name);
   ```

3. **Exit codes matter**:
   - `0` = Success (continue)
   - Non-zero = Failure (may block the action)

## Best Practices

### 1. Be Specific

Only process events relevant to your hook:
```javascript
// Good
if (input.hook_event_name !== 'PreToolUse') {
  process.exit(0);
}

// Better
if (input.tool_name !== 'Bash' || 
    !input.tool_input.command.includes('git')) {
  process.exit(0);
}
```

### 2. Fail Fast

Exit early if the event isn't relevant:
```javascript
// Check event type first
if (input.hook_event_name !== 'PostToolUse') return;

// Then check tool
if (!['Write', 'Edit'].includes(input.tool_name)) return;

// Then check file
if (!input.tool_input.file_path.endsWith('.js')) return;

// Now do your actual work...
```

### 3. Handle Errors Gracefully

Always wrap operations in try-catch:
```javascript
try {
  const result = someOperation(input);
  console.log('✅ Check passed');
} catch (error) {
  console.error('❌ Check failed:', error.message);
  process.exit(1);
}
```

### 4. Provide Clear Feedback

Help users understand what your hook is doing:
```javascript
console.log('🔍 Checking for security vulnerabilities...');
// ... do checks ...
console.log('✅ No vulnerabilities found');
```

### 5. Performance Matters

- Keep hooks fast (< 1 second ideally)
- Cache expensive operations
- Use async operations when possible

## Complete Example: Multi-Event Hook

Here's a complete hook that handles multiple events:

```javascript
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Configuration
const MAX_FILE_SIZE = 10000;
const FORBIDDEN_COMMANDS = ['rm -rf /', 'sudo rm -rf'];

// Read input
let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(inputData);
    handleEvent(input);
  } catch (error) {
    console.error('❌ Failed to parse input:', error.message);
    process.exit(1);
  }
});

function handleEvent(input) {
  console.log(`🪝 ${input.hook_event_name} event received`);
  
  switch (input.hook_event_name) {
    case 'PreToolUse':
      if (input.tool_name === 'Bash') {
        checkBashCommand(input.tool_input.command);
      }
      break;
      
    case 'PreWrite':
      checkFileWrite(input.file_path, input.content);
      break;
      
    case 'PostToolUse':
      if (input.tool_response && !input.tool_response.success) {
        console.log(`⚠️  ${input.tool_name} failed`);
      }
      break;
      
    case 'Stop':
      console.log('👋 Session complete!');
      break;
  }
}

function checkBashCommand(command) {
  // Check for dangerous commands
  for (const forbidden of FORBIDDEN_COMMANDS) {
    if (command.includes(forbidden)) {
      console.error(`❌ Dangerous command blocked: ${command}`);
      process.exit(1);
    }
  }
  
  // Warn about sudo
  if (command.includes('sudo')) {
    console.warn('⚠️  Warning: sudo command detected');
  }
  
  console.log('✅ Bash command approved');
}

function checkFileWrite(filePath, content) {
  // Check file size
  if (content.length > MAX_FILE_SIZE) {
    console.error(`❌ File too large: ${content.length} chars`);
    process.exit(1);
  }
  
  // Check file extension
  const ext = path.extname(filePath);
  if (ext === '.env' && content.includes('API_KEY')) {
    console.warn('⚠️  Warning: Writing API key to .env file');
  }
  
  console.log('✅ File write approved');
}
```

## Next Steps

1. **Create your hook** using the templates above
2. **Test it locally** with sample JSON inputs
3. **Add it to your project**:
   ```bash
   # Copy to hooks directory
   cp my-hook.js .claude/hooks/
   
   # Make it executable
   chmod +x .claude/hooks/my-hook.js
   
   # Add to config.cjs
   # Edit .claude/hooks/config.cjs to include your hook
   ```

4. **Share your hooks** with the community!

Remember: Hooks have full access to the event context via stdin. Use this power wisely to create hooks that make Claude Code safer, more efficient, and more enjoyable to use.