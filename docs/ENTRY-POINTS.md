# Claude Hooks Universal Entry Point System

This document explains the simplified universal entry point system for Claude hooks that enables dynamic hook management without restarting Claude.

## Overview

The universal entry point system replaces individual hook registrations in `settings.json` with a single entry point that dynamically loads hook configurations from a configuration file.

### Benefits

- **Never restart Claude** - Change hooks by editing config.cjs
- **Ultra-simple settings.json** - Only 1 entry point for all events
- **Faster iteration** - Test and modify hooks instantly
- **Minimal code** - ~50 lines instead of 500+

## Architecture

### 1. Universal Entry Point

One single entry point handles all hook events:

- `universal-hook` - Handles all Claude hook events including:
  - **PreToolUse** - Before tools execute (Bash, Write, Edit, etc.)
  - **PostToolUse** - After tools complete
  - **Stop** - When Claude finishes responding
  - **SubagentStop** - When a Task subagent finishes
  - **PreWrite** - Before writing files
  - **PostWrite** - After writing files
  - **PreCompact** - Before context compaction
  - **Notification** - For user notifications

### 2. Hook Input Data

Hooks receive comprehensive event data via stdin as JSON:

```typescript
// All events include:
{
  session_id: string,
  transcript_path: string,
  hook_event_name: string
}

// Tool events (PreToolUse, PostToolUse) add:
{
  tool_name: string,
  tool_input: {
    command?: string,    // For Bash
    file_path?: string,  // For Write/Edit
    content?: string,    // For Write/Edit
    pattern?: string,    // For Grep
    // ... other tool-specific fields
  }
}

// PostToolUse also adds:
{
  tool_response: {
    success?: boolean,
    filePath?: string,
    error?: string,
    // ... tool-specific response data
  }
}

// Write events (PreWrite, PostWrite) include:
{
  file_path: string,
  content: string,
  success?: boolean  // PostWrite only
}

// Stop events include:
{
  stop_hook_active: boolean
}
```

### 3. Configuration File

All hook routing is controlled by `.claude/hooks/config.cjs`:

```javascript
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
```

### 3. Hook Resolution

1. Claude triggers event → Universal hook command runs
2. Reads event type from input (`hook_event_name`)
3. Loads fresh config.cjs
4. Executes appropriate hooks via `exec` command

## Setup

### One-time settings.json configuration:

```json
{
  "_comment": "Claude Code hooks - universal entry point",
  "hooks": {
    "PreToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli universal-hook"
      }]
    }],
    "PostToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli universal-hook"
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli universal-hook"
      }]
    }],
    "PreWrite": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli universal-hook"
      }]
    }],
    "PostWrite": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli universal-hook"
      }]
    }]
  }
}
```

## Configuration Reference

### Simple Array Format (Recommended)

```javascript
module.exports = {
  preToolUse: ['hook1', 'hook2'],
  postToolUse: ['hook3'],
  stop: ['hook4', 'hook5'],
  preWrite: [],
  postWrite: []
};
```

### Advanced Pattern Matching (Optional)

You can use pattern matching for more granular control:

```javascript
module.exports = {
  // Tool command pattern matching
  preToolUse: {
    'Bash': {
      '^git\\s+commit': ['typescript-check', 'lint-check'],
      '^npm\\s+install': ['check-package-age']
    },
    'Write|Edit': ['auto-formatter']
  },
  
  // File path pattern matching
  preWrite: {
    '\\.test\\.(js|ts)$': ['test-validator'],
    'package\\.json$': ['package-validator'],
    '\\.md$': ['markdown-linter']
  },
  
  postToolUse: ['code-quality-validator'],
  stop: ['doc-compliance'],
  subagentStop: ['task-summary']
};
```

## Examples

### Add a New Hook

Edit `.claude/hooks/config.cjs`:

```javascript
// Before
preToolUse: ['typescript-check'],

// After - Added lint-check
preToolUse: ['typescript-check', 'lint-check'],
```

Changes take effect immediately!

### Disable a Hook Temporarily

Simply remove it from the array:

```javascript
stop: [
  'doc-compliance',
  // 'task-summary',  // Disabled temporarily
  'notification'
]
```

## Troubleshooting

### Hooks Not Running

1. Check that config.cjs exists in `.claude/hooks/`
2. Verify config.cjs syntax is valid
3. Check hook names match available hooks (run `npx claude-code-hooks-cli list`)

### Testing

Test the universal hook directly with complete event data:

```bash
# Test Stop event
echo '{
  "session_id": "test-123",
  "transcript_path": "/path/to/transcript.jsonl",
  "hook_event_name": "Stop",
  "stop_hook_active": true
}' | npx claude-code-hooks-cli universal-hook

# Test PreToolUse event
echo '{
  "session_id": "test-123",
  "transcript_path": "/path/to/transcript.jsonl",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {"command": "git commit -m \"test\""}
}' | npx claude-code-hooks-cli universal-hook

# Test PreWrite event
echo '{
  "session_id": "test-123",
  "transcript_path": "/path/to/transcript.jsonl",
  "hook_event_name": "PreWrite",
  "file_path": "/src/test.js",
  "content": "console.log(\"test\");"
}' | npx claude-code-hooks-cli universal-hook
```

## Best Practices

1. **Keep it simple** - Start with arrays, add patterns only if needed
2. **Test changes** - Run test commands to verify hooks work
3. **Use meaningful names** - Hook names should describe what they do

## Migration from Old System

If you had the previous multi-entry-point system:

1. Your settings.json already uses `universal-hook` commands
2. Rename `.claude/hooks/config.js` to `.claude/hooks/config.cjs`
3. Simplify the configuration to use arrays instead of nested patterns (unless needed)

That's it! The new system is designed to be as simple as possible while maintaining all functionality.