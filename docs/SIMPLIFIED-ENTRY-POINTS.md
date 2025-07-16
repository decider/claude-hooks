# Simplified Entry Points System

This document describes the simplified entry points system for Claude hooks.

## Overview

The entry points system provides a clean interface between Claude and your hooks. All hook configuration is centralized in `.claude/hooks/config.js`, which can be edited without restarting Claude.

## Architecture

### 1. Settings.json
Claude reads `.claude/settings.json` which defines entry points for each event type:
- `PreToolUse` → `npx claude-code-hooks-cli pre-tool-use`
- `PostToolUse` → `npx claude-code-hooks-cli post-tool-use`
- `PreWrite` → `npx claude-code-hooks-cli pre-write`
- `PostWrite` → `npx claude-code-hooks-cli post-write`
- `Stop` → `npx claude-code-hooks-cli stop`

### 2. Entry Points
Each entry point:
1. Reads JSON input from Claude via stdin
2. Loads configuration from `.claude/hooks/config.js`
3. Matches tools/patterns based on the configuration
4. Executes matching hooks by spawning `npx claude-code-hooks-cli exec <hook>`
5. Passes the JSON data to hooks via stdin

### 3. Configuration
Edit `.claude/hooks/config.js` to control which hooks run:

```javascript
module.exports = {
  preToolUse: {
    'Bash': {
      '^npm\\s+install': ['check-package-age'],
      '^git\\s+commit': ['lint-check', 'typescript-check']
    }
  },
  postToolUse: {
    'Write|Edit': ['code-quality-validator']
  },
  stop: ['task-completion-notify']
};
```

## Key Benefits
- **Dynamic configuration**: Edit config.js without restarting Claude
- **Pattern matching**: Use regex patterns to match specific commands or file paths
- **Tool matching**: Target specific Claude tools or use wildcards
- **Simple debugging**: Set `VERBOSE=true` or `DEBUG=true` for detailed logs

## Communication Flow
1. Claude sends JSON data to entry point via stdin
2. Entry point processes configuration and routing
3. Entry point spawns hook execution with JSON data
4. Hook output goes to stdout (visible to Claude)
5. Optional debug logs go to stderr (visible in terminal)