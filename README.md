# Claude Code Hooks - Your Hook Manager / CLI

Professional hook management system for Claude Code - TypeScript-based validation, quality checks, and hook management across environments.

[![npm version](https://badge.fury.io/js/claude-code-hooks-cli.svg)](https://www.npmjs.com/package/claude-code-hooks-cli)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Core Features

🎯 **Essential Built-in Hooks** - Pre-built validation and quality hooks ready to use  
🔧 **Hook Management Tool** - Easy add/remove hooks across different Claude environments  
📁 **Multi-Environment Support** - Manage hooks for local, global, project, and team settings  
🛡️ **Settings Validation** - Automatic validation when loading/saving hook configurations  
✅ **CLI Validation Command** - `claude-hooks validate` to check settings files  
⚡ **TypeScript-Powered** - Full type safety with modern JavaScript features  
🎮 **Interactive CLI** - `claude-hooks` command for all hook management needs

## Installation

```bash
npm install -D claude-code-hooks-cli
```

## Getting Started

### Quick Setup (5 seconds)
```bash
npm install -g claude-code-hooks-cli
claude-hooks init
```

### Interactive Setup Flow

When you run `claude-hooks init`:

**1. Choose setup mode:**
```
How would you like to set up hooks?

❯ Quick setup (recommended defaults)
  Custom setup (choose your hooks)
```

**2. Select where to save settings:**
```
Where would you like to create the settings file?

❯ Project (.claude/settings.json) - Team hooks, committed to git
  Global (~/.claude/settings.json) - Your default hooks
  Local (.claude/settings.local.json) - Personal hooks, git ignored
```

That's it! Your hooks are now protecting your Claude Code sessions.

### Advanced: Hook Manager

For custom hook configuration, use the interactive manager:

```bash
claude-hooks manage
```

**Location Selection Screen:**
```
Claude Hooks Manager

──────────────────────────────────────────────────
Hook Name                     Calls      Last Called
──────────────────────────────────────────────────
typescript-check              12         2 minutes ago
code-quality-validator        8          5 minutes ago
check-package-age            3          1 hour ago
──────────────────────────────────────────────────

↑/↓: Navigate  Enter: Select  Q/Esc: Exit

❯ Project (.claude/settings.json) (3 hooks) - Team hooks, committed to git
  Local (.claude/settings.local.json) (0 hooks) - Personal hooks, git ignored
  Global (~/.claude/settings.json) (0 hooks) - Your default hooks
  ──────────────
  📋 View recent logs
  📊 Tail logs (live)
  ──────────────
  ✕ Exit
```

**Hook Selection Screen:**
```
Hook Manager

↑/↓: Navigate  Enter: Toggle & Save  A: Select all  D: Deselect all  Q/Esc: Quit

❯◉ typescript-check                        (PreToolUse)
 ◉ code-quality-validator                  (PostToolUse)
 ◉ check-package-age                       (PreToolUse)
 ◯ lint-check                              (PreToolUse)
 ◯ test-check                              (PreToolUse)
 ◯ task-completion-notify                  (Stop)

──────────────────────────────────────────────────────────────────────────────

Description: TypeScript type checking before git commits
```


## How It Works

All hooks run directly from the npm package via TypeScript commands. Your `.claude/settings.json` will contain commands like:

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

## Writing Custom Hooks

Want to create your own hooks? Check out:
- 📖 **[Hook Development Guide](docs/HOOK-DEVELOPMENT.md)** - Complete guide with event data structures
- 💡 **[Example Hooks](examples/hooks/)** - Working examples: command logger, file validator, multi-event monitor
- 🔧 **[Entry Points Docs](docs/ENTRY-POINTS.md)** - How the universal hook system works

Quick example of a custom hook:
```javascript
#!/usr/bin/env node
// Read event data from stdin
let input = '';
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  const data = JSON.parse(input);
  console.log(`Event: ${data.hook_event_name}`);
  
  if (data.tool_name === 'Bash') {
    console.log(`Command: ${data.tool_input.command}`);
  }
});
```

## Available Hooks

### Core Validation Hooks
- **typescript-check** - Validates TypeScript code for type errors
- **lint-check** - Runs ESLint/Prettier checks on your code
- **test-check** - Executes your test suite to ensure code quality
- **code-quality-validator** - Enforces clean code standards on file edits

### Utility Hooks
- **check-package-age** - Prevents installation of outdated npm/yarn packages
- **task-completion-notify** - Notifies when tasks are completed

### Project-Specific Hooks
The hook manager can now automatically discover hooks defined in your project! Create a `.claude/hooks.json` file to share hook templates with your team:

```json
{
  "project-lint": {
    "event": "PreToolUse",
    "matcher": "Bash",
    "pattern": "^git\\s+commit",
    "description": "Run project-specific linting rules",
    "command": "./scripts/lint.sh"
  },
  "security-scan": {
    "event": "PreToolUse",
    "matcher": "Bash",
    "pattern": "^npm\\s+(install|i)",
    "description": "Scan dependencies for vulnerabilities",
    "command": "./scripts/security-check.sh"
  }
}
```

These hooks will automatically appear in the hook manager with a `[project]` label!

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
- `project` - `.claude/settings.json` (recommended)
- `local` - `.claude/settings.local.json`
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
**Validate hook settings files** - Ensures configurations are properly structured.

Validates JSON syntax, hook structure, event names, tool matchers, and regex patterns.

```bash
# Validate all settings files
claude-hooks validate

# Validate specific file
claude-hooks validate claude/settings.json

# Show detailed validation information
claude-hooks validate -v
```

The validator checks:
- ✅ Valid JSON syntax and structure
- ✅ Correct event names (PreToolUse, PostToolUse, Stop)
- ✅ Valid tool matchers (Bash, Write, Edit, etc.)
- ✅ Proper regex pattern syntax
- ✅ Required fields and types
- ✅ Logging configuration (if present)

### `claude-hooks exec <hook>`
Execute a specific hook. This is used internally by Claude Code.

*Note: All commands are also available with the full name `claude-code-hooks-cli`*

## Available Hooks

### Built-in Hooks

- **typescript-check** - TypeScript type checking before git commits
- **lint-check** - Code linting (ESLint, etc.) before git commits  
- **test-check** - Run test suite before various operations
- **code-quality-validator** - Enforces clean code standards after file edits
- **check-package-age** - Prevents installation of outdated npm/yarn packages
- **task-completion-notify** - System notifications when Claude finishes (Stop event)

### Project Hooks

You can discover project-specific hooks by creating `.claude/hooks.json` in your project.

## Configuration Levels

- **Project** (`.claude/settings.json`) - Shared with your team, committed to git (recommended)
- **Local** (`.claude/settings.local.json`) - Personal settings, git ignored
- **Global** (`~/.claude/settings.json`) - Applies to all your projects

## What's New

### v2.4.0 (Latest)
- 🔍 **Hook Discovery System** - Automatically finds project hooks in `.claude/hooks.json`
- 🏷️ **Hook Source Labels** - Visual indicators for built-in, project, and custom hooks
- 📂 **Project Hook Templates** - Share team-specific hooks via version control
- 🛡️ **Template Validation** - Automatic validation of discovered hook templates
- 🎯 **Relative Path Support** - Project hooks can use relative script paths

### v2.3.0
- 🎯 **Simplified hook system** - Consolidated to essential validation hooks
- 🛡️ **Improved error handling** - Better exit codes and error messages
- 📁 **Common validation library** - Shared functionality for consistency
- 🚀 **Enhanced CLI commands** - Better hook management experience
- 🧹 **Removed deprecated hooks** - Cleaner, more focused hook set
- ✅ **Hook Settings Validation** - Automatic validation prevents invalid configurations
- 📋 **Validate Command** - New `claude-hooks validate` command for checking settings

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
