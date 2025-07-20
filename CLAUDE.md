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

## Architecture Notes
- Written in Python for portability
- Hook scripts stored in `.claude/hooks/`
- Configuration in `.claude/settings.json`
- Three universal entry points: PreToolUse, PostToolUse, Stop
- Each hook validates specific conditions and provides feedback

---
_Manually maintained project documentation_