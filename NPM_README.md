# claude-code-hooks-cli

Professional TypeScript-based NPM package for Claude Code hooks - no file copying needed!

## Installation

```bash
npm install -D claude-code-hooks-cli
```

## Quick Start

1. Generate your Claude settings:
```bash
npx claude-code-hooks-cli init
```

2. That's it! Hooks will run automatically in Claude Code.

## How It Works

All hooks run directly from the npm package via TypeScript-compiled `npx` commands in your `claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "npx claude-code-hooks-cli exec stop-validation"
      }]
    }]
  }
}
```

## Commands

- `npx claude-code-hooks-cli init` - Interactive setup with TypeScript-powered CLI
- `npx claude-code-hooks-cli list` - See all available hooks
- `npx claude-code-hooks-cli manage` - Interactive hook manager
- `npx claude-code-hooks-cli exec <hook>` - Execute a hook (used by Claude)

## Available Hooks

- **stop-validation** - Validates TypeScript and linting before allowing Claude to stop
- **check-package-age** - Prevents installation of outdated npm/yarn packages
- **code-quality-validator** - Enforces clean code standards on file edits
- And more! Run `npx claude-code-hooks-cli list` to see all.

## Benefits

✅ **TypeScript-powered** - Modern, type-safe implementation  
✅ **Always up-to-date** - Just `npm update`  
✅ **No file management** - Everything runs from node_modules  
✅ **Version locked** - Consistent behavior via package.json  
✅ **Interactive CLI** - User-friendly setup and management  
✅ **Works everywhere** - Compatible with npm, yarn, pnpm  
✅ **Project-local** - Uses `claude/` directory structure  

## Configuration Levels

- `--level project` - `claude/settings.json` (git tracked, recommended)
- `--level project-alt` - `.claude/settings.json` (legacy format)
- `--level local` - `claude/settings.local.json` (git ignored)
- `--level global` - `~/.claude/settings.json` (all projects)

## Development

This project uses TypeScript:

```bash
npm run build  # Compile TypeScript
npm run dev    # Watch mode
```

## Publishing

To publish this package:

```bash
npm run build  # Compile TypeScript first
npm login
npm publish --access public
```