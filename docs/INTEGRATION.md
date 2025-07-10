# Integrating Claude Hooks into Your Project

## Quick Start (Recommended)

Install the Claude Hooks CLI package:

```bash
npm install -D claude-code-hooks-cli@latest
# or
yarn add -D claude-code-hooks-cli@latest
```

Then run the interactive hook manager:

```bash
npx claude-hooks
```

## Installation Methods

### 1. NPM Package (Recommended)

The easiest way to use Claude Hooks is via the npm package:

```bash
# Install as dev dependency
npm install -D claude-code-hooks-cli@latest

# Run the interactive manager
npx claude-hooks

# Or initialize hooks for your project
npx claude-hooks init
```

### 2. Global Installation

For using hooks across all your projects:

```bash
# Install globally
npm install -g claude-code-hooks-cli@latest

# Run from anywhere
claude-hooks
```

### 3. Project-Specific Hooks

Create a `.claude/hooks.json` file in your project to define custom hooks:

```json
{
  "my-custom-lint": {
    "event": "PreToolUse",
    "matcher": "Bash",
    "pattern": "^git\\s+commit",
    "description": "Run my custom linting",
    "command": "./scripts/my-lint.sh"
  }
}
```

These hooks will appear in the hook manager with a `[project]` label.

## Hook Discovery

The CLI automatically discovers hooks from multiple sources:

1. **Built-in hooks** - Shipped with the package (typescript-check, lint-check, etc.)
2. **Project hooks** - Defined in `.claude/hooks.json`
3. **Custom hooks** - Added manually through the manager

## Configuration Locations

Claude Code looks for settings in these locations (in order):

1. `./claude/settings.json` - Project-specific settings
2. `~/.config/claude/settings.json` - User settings (XDG config)
3. `~/.claude/settings.json` - User settings (home directory)

## Updating

To update the Claude Hooks CLI:

```bash
# If installed locally
npm update claude-code-hooks-cli

# If installed globally
npm update -g claude-code-hooks-cli
```

## Legacy Integration Methods

For projects that need to vendor hooks directly (not recommended), see the [legacy integration guide](./INTEGRATION-LEGACY.md).