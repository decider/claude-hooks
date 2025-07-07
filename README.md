# claude-code-hooks-cli

Professional hook management system for Claude Code - TypeScript-based validation, quality checks, and hook management across environments.

[![npm version](https://badge.fury.io/js/claude-code-hooks-cli.svg)](https://www.npmjs.com/package/claude-code-hooks-cli)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Core Features

🎯 **Essential Built-in Hooks** - Pre-built validation and quality hooks ready to use  
🔧 **Hook Management Tool** - Easy add/remove hooks across different Claude environments  
📁 **Multi-Environment Support** - Manage hooks for local, global, project, and team settings  
🛡️ **Hook Validation** - Ensures all hooks are properly structured and secure  
⚡ **TypeScript-Powered** - Full type safety with modern JavaScript features  
🎮 **Interactive CLI** - `claude-hooks` command for all hook management needs

## Installation

```bash
npm install -D claude-code-hooks-cli
```

## Getting Started

Welcome to Claude Hooks! Here's your journey from installation to running hooks:

### Step 1: Enter Claude Hooks
```bash
npm install -D claude-code-hooks-cli
claude-hooks init
```

```
┌─────────────────────────────────────────┐
│          Welcome to Claude Hooks!      │
│                                         │
│  🎯 Essential validation hooks          │
│  🔧 Multi-environment management        │
│  🛡️ Built-in security validation       │
│                                         │
│         Let's get you set up...         │
└─────────────────────────────────────────┘
```

### Step 2: Select Your Environment
Choose where to manage your hooks:

```
┌─────────────────────────────────────────┐
│  Where would you like to manage hooks?  │
│                                         │
│  ▶ Project (claude/settings.json)      │
│    Local   (claude/settings.local.json)│
│    Global  (~/.claude/settings.json)   │
│                                         │
│  Current hooks: 0 configured            │
└─────────────────────────────────────────┘
```

### Step 3: Choose Your Hooks
Interactive hook selection:

```
┌─────────────────────────────────────────┐
│     Select hooks to install/remove:     │
│                                         │
│  [✓] typescript-check    (Quality)     │
│  [✓] lint-check         (Code Style)   │
│  [✓] test-check         (Validation)   │
│  [ ] code-quality       (Advanced)     │
│  [ ] package-age        (Security)     │
│                                         │
│  Space to toggle, Enter to continue     │
└─────────────────────────────────────────┘
```

### Step 4: Monitor Hook Performance
View real-time statistics:

```bash
claude-hooks stats
```

```
┌─────────────────────────────────────────┐
│            Hook Statistics              │
│                                         │
│  typescript-check:  ✅ 47 runs (2m ago) │
│  lint-check:       ✅ 52 runs (1m ago)  │
│  test-check:       ⚠️  41 runs (5m ago)  │
│                                         │
└─────────────────────────────────────────┘
```

### Step 5: Live Log Monitoring
Watch hooks in action:

```bash
claude-hooks logs --follow
```

```
┌─────────────────────────────────────────┐
│               Live Hook Logs            │
│                                         │
│ [05:48:55] [INFO] [check-package-age]   │
│           Hook completed (exit code: 0) │
│ [05:49:03] [INFO] [quality-check]       │
│           Hook started                  │
│ [05:49:11] [ERROR] [quality-check]      │
│           Hook failed (exit code: 2)    │
│           ⚠️ Fix quality check failures  │
│                                         │
│  Press Ctrl+C to stop following         │
└─────────────────────────────────────────┘
```

That's it! Your hooks are now protecting your Claude Code sessions.

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

Run `claude-hooks list` to see all available hooks.

## Commands

### `claude-hooks init`
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

### `claude-hooks manage`
**Interactive hook manager** - TypeScript-based configuration interface.

Same as running `init` and choosing "Custom setup". Use this when you want to skip the setup mode prompt.

### `claude-hooks list`
Show all available hooks with descriptions (TypeScript compiled).

### `claude-hooks stats`
Display hook performance statistics and success rates.

### `claude-hooks logs [--follow]`
View hook execution logs. Use `--follow` for live monitoring.

### `claude-hooks validate [path]`
Validate hook files to ensure they're properly structured and secure.

### `claude-hooks exec <hook>`
Execute a specific hook. This is used internally by Claude Code.

*Note: All commands are also available with the full name `claude-code-hooks-cli`*

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

## Roadmap

### 🚀 Coming Soon

- **Hook Package Manager** - Discover and import hooks from GitHub repositories
- **Advanced Validation System** - Comprehensive hook validation with security checks and auto-fix
- **Task Completion Enforcement** - Hooks that prevent Claude from exiting before completing all tasks
- **Package Similarity Detection** - Prevents installing duplicate packages by detecting similar existing dependencies
- **Method Similarity Indexer** - Prevents duplicate code by detecting similar methods across the repository
- **Continuous UI Improvement** - Automated UI enhancement using visual feedback and design analysis
- **Prompt Optimization System** - Continuous AI prompt refinement based on conversation metrics
- **Shiny Windows Delight** - Perpetual UI enhancement system for adding delightful micro-interactions

### 🎯 Planned Features

- **Repo-Based Hook Discovery** - Automatically find and catalog hooks in visited repositories
- **Hook Marketplace** - Community-driven hook sharing and rating system
- **AI-Powered Hook Suggestions** - Recommend hooks based on project analysis
- **Multi-Armed Bandit Testing** - A/B test different hook configurations automatically
- **Visual Hook Designer** - GUI for creating hooks without coding

See our [ideas documentation](./docs/ideas-for-hooks/) for detailed specifications of upcoming features.

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