# Quick Install: Stop Validation Hook

This guide helps you add the stop validation hook to a project that already has claude-hooks installed.

## Prerequisites
- claude-hooks already installed (hooks exist in `./claude/hooks/`)
- A TypeScript project (or monorepo)

## Installation Steps

### 1. Copy the Stop Validation Hook

```bash
# From the claude-hooks repository, copy the hook to your project
cp /path/to/claude-hooks/hooks/stop-validation.sh ./claude/hooks/
chmod +x ./claude/hooks/stop-validation.sh
```

### 2. Update Your Settings

Edit `./claude/settings.json` to add the stop validation hook to the `Stop` event.

If you have the old format (`toolHooks`), update to the new format:

```json
{
  "hooks": {
    "PreToolUse": [
      // ... your existing PreToolUse hooks ...
    ],
    "PostToolUse": [
      // ... your existing PostToolUse hooks ...
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "./claude/hooks/stop-validation.sh"
          },
          {
            "type": "command",
            "command": "./claude/hooks/task-completion-notify.sh"
          }
        ]
      }
    ]
  }
}
```

If you already have the new format, just add the stop-validation hook to the Stop event:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "./claude/hooks/stop-validation.sh"
      }
      // ... any other stop hooks ...
    ]
  }
]
```

### 3. Verify Installation

Test that the hook is working:

```bash
# Create a TypeScript file with an error
echo 'const x: string = 123;' > test-error.ts

# The hook should prevent Claude from stopping until this is fixed
```

## What This Hook Does

- **Automatically finds** all TypeScript projects in your repo (including monorepos)
- **Runs TypeScript checks** (`tsc --noEmit`) on each project
- **Runs lint checks** if available
- **Blocks Claude from stopping** if any errors are found
- **Forces fixes** before allowing the conversation to end

## Supported Project Structures

- Single TypeScript projects
- Monorepos (apps/*, packages/*, etc.)
- Projects with custom scripts (typecheck, type-check, tsc)
- Projects without custom scripts (falls back to tsc --noEmit)

## Troubleshooting

If the hook isn't working:

1. Check logs: `cat ~/.local/share/claude-hooks/logs/hooks.log | grep stop-validation`
2. Ensure the hook is executable: `chmod +x ./claude/hooks/stop-validation.sh`
3. Verify your settings.json is using the new format (hooks, not toolHooks)
4. Make sure you have TypeScript projects (with tsconfig.json or typescript in package.json)

## Configuration

The hook respects these environment variables:
- `CLAUDE_LOG_ENABLED=false` - Disable logging
- `CLAUDE_LOG_LEVEL=DEBUG` - Show debug logs

## Note for AI Assistants

When installing this hook:
1. Check if `./claude/hooks/` exists first
2. Verify the settings.json format before modifying
3. Test the hook works by creating a TypeScript error and trying to stop
4. The hook should block stopping and show which projects have errors