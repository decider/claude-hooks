# Project Hooks Directory

This directory contains project-specific hook configurations for Claude Code.

## hooks.json

The `hooks.json` file defines custom hooks that are specific to this project. These hooks will automatically appear in the Claude Hooks manager when developers run `claude-hooks manage`.

### Example Structure

```json
{
  "hook-name": {
    "event": "PreToolUse|PostToolUse|Stop",
    "matcher": "Tool names to match (optional)",
    "pattern": "Regex pattern to match (optional)",
    "description": "What this hook does",
    "command": "Command to execute (optional)"
  }
}
```

### Fields

- **event** (required): When the hook runs - `PreToolUse`, `PostToolUse`, or `Stop`
- **matcher** (optional): Which Claude tools trigger this hook (e.g., `Bash`, `Write`, `Edit`)
- **pattern** (optional): Regex pattern to match against tool input
- **description** (required): Human-readable description shown in the hook manager
- **command** (optional): Custom command to run. If not specified, uses `npx claude-code-hooks-cli exec <hook-name>`

### Using Relative Paths

If your hook needs to run a script from your project, you can use relative paths:

```json
{
  "project-lint": {
    "event": "PreToolUse",
    "matcher": "Bash",
    "pattern": "^git\\s+commit",
    "description": "Run project-specific linting",
    "command": "./scripts/lint.sh"
  }
}
```

The command will be executed from the project root directory.