# @claude-hooks/cli

Simple NPM package for Claude Code hooks - no file copying needed!

## Installation

```bash
npm install -D @claude-hooks/cli
```

## Quick Start

1. Generate your Claude settings:
```bash
npx claude-hooks init
```

2. That's it! Hooks will run automatically in Claude Code.

## How It Works

All hooks run directly from the npm package via `npx` commands in your settings.json:

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "npx @claude-hooks/cli exec stop-validation"
      }]
    }]
  }
}
```

## Commands

- `npx claude-hooks init` - Generate settings.json with recommended hooks
- `npx claude-hooks list` - See all available hooks
- `npx claude-hooks exec <hook>` - Execute a hook (used by Claude)

## Available Hooks

- **stop-validation** - Validates TypeScript and linting before allowing Claude to stop
- **check-package-age** - Prevents installation of outdated npm/yarn packages
- **code-quality-validator** - Enforces clean code standards on file edits
- And more! Run `npx claude-hooks list` to see all.

## Benefits

✅ Always up-to-date (just `npm update`)  
✅ No file management needed  
✅ Version locked via package.json  
✅ Works with npm, yarn, pnpm  
✅ Super simple setup  

## Configuration Levels

- `--level project` - .claude/settings.json (git tracked, default)
- `--level local` - .claude/settings.local.json (git ignored)
- `--level global` - ~/.claude/settings.json (all projects)

## Publishing

To publish this package:

```bash
npm login
npm publish --access public
```