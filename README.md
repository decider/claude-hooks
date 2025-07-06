# claude-code-hooks-cli

Simple NPM package for Claude Code hooks - Run validation and quality checks in Claude.

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

All hooks run directly from the npm package. Your settings.json will contain commands like:

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

- **stop-validation** - Validates TypeScript and linting before allowing Claude to stop
- **check-package-age** - Prevents installation of outdated npm/yarn packages  
- **code-quality-validator** - Enforces clean code standards on file edits
- **code-quality-primer** - Provides code quality context before edits
- **pre-commit-check** - Runs checks before git commits
- And more! Run `npx claude-code-hooks-cli list` to see all available hooks.

## Commands

### `npx claude-code-hooks-cli init`
**Initialize Claude hooks** - Choose between quick setup or custom configuration.

**Interactive mode** (default):
1. First prompts for setup mode:
   - **Quick setup** - Installs recommended hooks (4 defaults)
   - **Custom setup** - Opens interactive manager to add/remove hooks

2. Then prompts for location (shows existing hook counts)

**Direct mode** with `--level <level>`:
- Goes straight to quick setup at specified location
- `project` - `.claude/settings.json`
- `project-alt` - `claude/settings.json`
- `local` - `.claude/settings.local.json`
- `global` - `~/.claude/settings.json`

### `npx claude-code-hooks-cli manage`
**Alias for custom setup** - Goes directly to the interactive hook manager.

Same as running `init` and choosing "Custom setup". Use this when you want to skip the setup mode prompt.

### `npx claude-code-hooks-cli list`
Show all available hooks with descriptions.

### `npx claude-code-hooks-cli exec <hook>`
Execute a specific hook. This is used internally by Claude Code.

## Configuration Levels

- **Project** (`.claude/settings.json`) - Shared with your team, committed to git
- **Local** (`.claude/settings.local.json`) - Personal settings, git ignored
- **Global** (`~/.claude/settings.json`) - Applies to all your projects

## Benefits

✅ **Always up-to-date** - Just run `npm update claude-code-hooks-cli`  
✅ **No file management** - Everything runs from node_modules  
✅ **Version locked** - Consistent behavior via package.json  
✅ **Works everywhere** - Compatible with npm, yarn, pnpm  
✅ **Super simple** - One command setup  

## Contributing

Contributions are welcome! Please check out the [claude-hooks repository](https://github.com/yourusername/claude-hooks).

## License

MIT