# Claude Hooks

A Python-based hook system for Claude Code that provides automatic validation and quality checks.

## Overview
This project provides Python hooks that integrate with Claude Code (claude.ai/code). Hooks allow you to run validation, linting, type checking, and other quality checks automatically during Claude sessions.

## Available Hooks

### Built-in Hooks
#### Code Quality
- **code-quality-validator**: Enforces clean code standards (function length, nesting, etc.) after file edits

#### Package Management
- **check-package-age**: Prevents installation of outdated npm/yarn packages

#### Notifications
- **task-completion-notify**: System notifications for completed tasks (optional)

## Installation
Run the installer to set up hooks in your project:
```bash
python3 install-hooks.py
```

## Configuration

### Hierarchical Configuration System
The hook system supports flexible, directory-specific configurations:

1. **Root Configuration**: `.claude/hooks.json` defines default hooks
2. **Directory Overrides**: Any directory can have `.claude-hooks.json` 
3. **Configuration Inheritance**: Settings cascade with local overrides

Example:
```
project/
├── .claude/hooks.json         # Default settings
├── backend/
│   └── .claude-hooks.json     # Stricter Python rules
└── frontend/
    └── .claude-hooks.json     # Different JS/React rules
```

### Hook Introspection
```bash
# See all hooks in your project
python3 hooks/list_hooks.py list

# Check which hooks apply to a specific file
python3 hooks/list_hooks.py explain src/app.py
```

## Architecture Notes
- Written in Python for portability (no external dependencies)
- Hook scripts stored in `.claude/hooks/`
- Main configuration in `.claude/hooks.json` (JSON format)
- Settings.json in `.claude/settings.json` for Claude integration
- Three universal entry points: PreToolUse, PostToolUse, Stop
- Each hook validates specific conditions and provides feedback
- Hooks receive configuration via CLAUDE_HOOK_CONFIG environment variable

---
_Manually maintained project documentation_