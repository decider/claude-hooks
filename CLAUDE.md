# Claude Hooks CLI

A command-line tool for managing Claude Code hooks - validation and quality checks that run automatically within Claude.

## Overview
This project provides a CLI tool to easily manage hooks for Claude Code (claude.ai/code). Hooks allow you to run validation, linting, type checking, and other quality checks automatically before certain actions in Claude.

## Hook Discovery System
The CLI can automatically discover project-specific hooks! Create a `.claude/hooks.json` file in your project:

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

These hooks will appear in the manager with a `[project]` label.

## Available Hooks

### Built-in Hooks
#### Code Quality
- **typescript-check**: TypeScript type checking before git commits
- **lint-check**: Code linting (ESLint, etc.) before git commits  
- **test-check**: Run test suite before various operations
- **code-quality-validator**: Enforces clean code standards (function length, nesting, etc.) after file edits

#### Package Management
- **check-package-age**: Prevents installation of outdated npm/yarn packages

#### Notifications
- **task-completion-notify**: System notifications for completed tasks

### Project Hooks
Discovered from `.claude/hooks.json` - shown with `[project]` label

### Custom Hooks
User-added hooks - shown with `[custom]` label

## Commands
- `npm run build` - Compile TypeScript to JavaScript
- `npm run dev` - Watch mode for development
- `npm run typecheck` - Type check without emitting
- `npm run prepublishOnly` - Build before publishing
- `npm run test` - Run tests (placeholder)
- `npm run lint` - Run linter (placeholder)

## Dependencies
- chalk@^5.3.0 - Terminal styling
- commander@^11.0.0 - CLI framework
- inquirer@^9.2.15 - Interactive prompts

## Custom Slash Commands
The project now includes custom Claude Code slash commands for enhanced workflow automation:

### GitHub Workflow Commands
- **`/gh:cpt`** - Complete GitHub workflow: commit → push → create PR → monitor CI/CD → fix failures → repeat until all checks pass
  - Automatically handles staged changes
  - Creates descriptive commits with proper attribution
  - Creates PRs with structured summaries
  - Monitors GitHub Actions every 30 seconds
  - Fixes failures and repeats until all checks pass

## Architecture Notes
- Written in TypeScript
- Modular design with separate commands
- Hook validation system
- Interactive UI for hook management
- Supports multiple settings file locations
- Custom slash commands for workflow automation

---
_Manually maintained project documentation_