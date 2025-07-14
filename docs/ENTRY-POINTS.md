# Claude Hooks Entry Points System

This document explains the new simplified entry point system for Claude hooks that enables dynamic hook management without restarting Claude.

## Overview

The entry point system replaces individual hook registrations in `settings.json` with a small set of universal entry points that dynamically load hook configurations from a single file.

### Benefits

- **Never restart Claude** - Change hooks by editing config.js
- **Simpler settings.json** - Only 4 entry points instead of dozens
- **Faster iteration** - Test and modify hooks instantly
- **Cleaner architecture** - All hook logic in one place

## Architecture

### 1. Entry Points

Four universal entry points handle all hook events:

- `pre-tool-use` - Runs before tools like Bash, Write, Edit
- `post-tool-use` - Runs after tools complete
- `stop` - Runs when Claude finishes a task
- `pre-write` - Runs before writing files

### 2. Configuration File

All hook routing is controlled by `.claude/hooks/config.js`:

```javascript
module.exports = {
  // PreToolUse: Runs before tools
  preToolUse: {
    'Bash': {
      '^git\\s+commit': ['typescript-check', 'lint-check'],
      '^npm\\s+install': ['check-package-age'],
    }
  },
  
  // PostToolUse: Runs after tools
  postToolUse: {
    'Write|Edit|MultiEdit': ['code-quality-validator'],
  },
  
  // Stop: Runs when Claude finishes
  stop: ['doc-compliance'],
  
  // PreWrite: Runs before writing files
  preWrite: {
    '\\.test-trigger$': ['self-test'],
  }
};
```

### 3. Hook Resolution

1. Claude triggers event → Entry point command runs
2. Entry point loads fresh config.js
3. Matches patterns against current context
4. Executes appropriate hooks via `exec` command
5. Logs all activity for debugging

## Migration Guide

### From Old System

If you have existing hooks in settings.json:

```bash
# Migrate automatically
npx claude-code-hooks-cli migrate

# Or migrate specific file
npx claude-code-hooks-cli migrate /path/to/settings.json
```

This will:
1. Backup your current settings.json
2. Replace hook registrations with entry points
3. Preserve your hook configurations in config.js

### Manual Setup

1. Update your settings.json:

```json
{
  "_comment": "Claude Code hooks - simplified entry points",
  "hooks": {
    "PreToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli pre-tool-use"
      }]
    }],
    "PostToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli post-tool-use"
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli stop"
      }]
    }],
    "PreWrite": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli pre-write"
      }]
    }]
  }
}
```

2. Create `.claude/hooks/config.js` with your hook mappings

## Configuration Reference

### PreToolUse

Matches tools and command patterns:

```javascript
preToolUse: {
  'ToolName': {
    'pattern': ['hook1', 'hook2'],
    '^regex.*pattern$': ['hook3']
  }
}
```

- **ToolName**: Bash, Write, Edit, Read, etc.
- **Pattern**: Regular expression to match against command/input
- **Hooks**: Array of hook names to execute

### PostToolUse

Matches tools after execution:

```javascript
postToolUse: {
  'Write|Edit|MultiEdit': ['code-quality-validator'],
  'Bash': ['command-logger']
}
```

### Stop

Simple array of hooks to run on task completion:

```javascript
stop: ['doc-compliance', 'task-summary', 'notification']
```

### PreWrite

Matches file paths before writing:

```javascript
preWrite: {
  '\\.ts$': ['typescript-formatter'],
  '\\.test\\.js$': ['test-validator'],
  'package\\.json$': ['package-validator']
}
```

## Examples

### Add a New Hook

Edit `.claude/hooks/config.js`:

```javascript
// Before
preToolUse: {
  'Bash': {
    '^git\\s+commit': ['typescript-check'],
  }
}

// After - Added lint-check
preToolUse: {
  'Bash': {
    '^git\\s+commit': ['typescript-check', 'lint-check'],
  }
}
```

Changes take effect immediately!

### Disable a Hook Temporarily

Simply comment it out:

```javascript
stop: [
  'doc-compliance',
  // 'task-summary',  // Disabled temporarily
  'notification'
]
```

### Test New Patterns

Add a test pattern and verify it works:

```javascript
preToolUse: {
  'Bash': {
    '^echo\\s+test': ['debug-hook'],  // Test pattern
    // ... existing patterns
  }
}
```

## Troubleshooting

### Hooks Not Running

1. Check logs: `.claude/logs/hooks-YYYY-MM-DD.log`
2. Verify config.js syntax is valid
3. Test pattern matching with the test suite
4. Enable verbose logging: `export CLAUDE_HOOK_VERBOSE=true`

### Pattern Not Matching

Test your regex:
```javascript
// In Node.js REPL
const pattern = '^git\\s+commit';
const command = 'git commit -m "test"';
console.log(new RegExp(pattern).test(command)); // Should print true
```

### Performance Issues

- Check hook execution times in logs
- Consider running heavy hooks only on Stop event
- Use more specific patterns to reduce hook calls

## Testing

Run the test suite to verify your configuration:

```bash
# Test all entry points
./test-entry-points.sh

# Test specific hook execution
echo '{"tool_name": "Bash", "tool_input": {"command": "git commit"}}' | \
  npx claude-code-hooks-cli pre-tool-use
```

## Best Practices

1. **Keep patterns specific** - Avoid overly broad matches
2. **Group related hooks** - Run multiple hooks for same pattern
3. **Use Stop for heavy tasks** - Don't slow down tool execution
4. **Log appropriately** - Use logger for debugging
5. **Test changes** - Verify patterns match as expected

## Advanced Usage

### Conditional Hooks

Use complex patterns for conditional execution:

```javascript
// Only on main branch commits
'^git\\s+commit.*--amend': ['amend-validator'],

// Only for specific file types
'npm\\s+publish.*\\.beta\\.': ['beta-checker']
```

### Tool Combinations

Match multiple tools with pipe syntax:

```javascript
'Write|Edit|MultiEdit': ['universal-validator'],
'Bash|exec': ['command-logger']
```

### Debug Mode

Create a debug configuration:

```javascript
// .claude/hooks/config.debug.js
module.exports = {
  preToolUse: {
    '*': { '*': ['debug-logger'] }  // Log everything
  }
};
```

Then swap configs for debugging.