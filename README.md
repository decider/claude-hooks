# claude-code-hooks-cli

Professional NPM package for Claude Code hooks - TypeScript-based validation and quality checks.

[![npm version](https://badge.fury.io/js/claude-code-hooks-cli.svg)](https://www.npmjs.com/package/claude-code-hooks-cli)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Installation

```bash
npm install -D claude-code-hooks-cli
```

## Quick Start

Generate your Claude settings:

```bash
npx claude-code-hooks-cli init
```

That's it! Hooks will run automatically in Claude Code.

## How It Works

All hooks run directly from the npm package via TypeScript commands. Your `claude/settings.json` will contain commands like:

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

## Available Hooks

### Core Validation Hooks
- **typescript-check** - Validates TypeScript code for type errors
- **lint-check** - Runs ESLint/Prettier checks on your code
- **test-check** - Executes your test suite to ensure code quality
- **code-quality-validator** - Enforces clean code standards on file edits

### Utility Hooks
- **check-package-age** - Prevents installation of outdated npm/yarn packages
- **claude-context-updater** - Updates CLAUDE.md with project information
- **task-completion-notify** - Notifies when tasks are completed

Run `npx claude-code-hooks-cli list` to see all available hooks.

## Commands

### `npx claude-code-hooks-cli init`
**Initialize Claude hooks** - TypeScript-powered interactive setup.

**Interactive mode** (default):
1. First prompts for setup mode:
   - **Quick setup** - Installs recommended hooks (4 defaults)
   - **Custom setup** - Opens interactive manager to add/remove hooks

2. Then prompts for location (shows existing hook counts)

**Direct mode** with `--level <level>`:
- Goes straight to quick setup at specified location
- `project` - `claude/settings.json` (recommended)
- `project-alt` - `.claude/settings.json` (legacy)
- `local` - `claude/settings.local.json`
- `global` - `~/.claude/settings.json`

### `npx claude-code-hooks-cli manage`
**Interactive hook manager** - TypeScript-based configuration interface.

Same as running `init` and choosing "Custom setup". Use this when you want to skip the setup mode prompt.

### `npx claude-code-hooks-cli list`
Show all available hooks with descriptions (TypeScript compiled).

### `npx claude-code-hooks-cli exec <hook>`
Execute a specific hook. This is used internally by Claude Code.

## Configuration Levels

- **Project** (`claude/settings.json`) - Shared with your team, committed to git (recommended)
- **Legacy Project** (`.claude/settings.json`) - Old format, still supported
- **Local** (`claude/settings.local.json`) - Personal settings, git ignored
- **Global** (`~/.claude/settings.json`) - Applies to all your projects

## What's New in v2.3.0

- 🎯 **Simplified hook system** - Consolidated to essential validation hooks
- 🛡️ **Improved error handling** - Better exit codes and error messages
- 📁 **Common validation library** - Shared functionality for consistency
- 🚀 **Enhanced CLI commands** - Better hook management experience
- 🧹 **Removed deprecated hooks** - Cleaner, more focused hook set

## Benefits

✅ **TypeScript-powered** - Full type safety and modern JavaScript features  
✅ **Always up-to-date** - Just run `npm update claude-code-hooks-cli`  
✅ **No file management** - Everything runs from node_modules  
✅ **Version locked** - Consistent behavior via package.json  
✅ **Works everywhere** - Compatible with npm, yarn, pnpm  
✅ **Interactive CLI** - Modern command-line interface with prompts  
✅ **Project-local config** - Uses `claude/` directory (not `~/.claude`)  

## Development

This project uses TypeScript. To develop:

```bash
npm install
npm run dev    # Watch mode
npm run build  # Compile TypeScript
```

Source files are in `src/` and compiled to `lib/`.

## Contributing

Contributions are welcome! This is a TypeScript project with modern tooling.

## License

MIT