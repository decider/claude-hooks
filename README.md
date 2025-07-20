# Claude Code Hooks

A lightweight Python-based hook system for Claude Code that provides automatic validation and quality checks.

## Overview

Claude Code Hooks allows you to set up automatic validation, quality checks, and notifications that run during your Claude Code sessions. The system uses Python scripts that integrate seamlessly with Claude's hook events.

## Features

- 🐍 **Python-based** - Simple, portable hook implementation
- ✅ **Code Quality Validation** - Enforces clean code standards
- 📦 **Package Age Checking** - Prevents installation of outdated packages
- 🔔 **Task Completion Notifications** - Get notified when Claude finishes tasks
- 🎯 **Easy Installation** - One command setup
- 🏗️ **Hierarchical Configuration** - Different rules for different directories
- 🔍 **Hook Introspection** - See which hooks apply to any file

## Installation

```bash
python3 install-hooks.py
```

This will:
1. Create a `.claude/` directory in your project
2. Copy all hook scripts to `.claude/hooks/`
3. Generate `.claude/settings.json` with hook configurations
4. Add `.claude/settings.local.json` to your `.gitignore`

## How It Works

The hook system uses three main entry points that Claude Code calls:
- **PreToolUse** - Runs before tools like Bash, Write, or Edit are executed
- **PostToolUse** - Runs after tools complete
- **Stop** - Runs when Claude stops or completes a task

Each hook receives event data via stdin and can:
- Provide suggestions and warnings
- Block operations that violate policies
- Send notifications
- Log activities

## Available Hooks

### Code Quality Validator
Enforces clean code standards on file edits:
- Maximum function length (30 lines)
- Maximum file length (200 lines)
- Maximum line length (100 characters)
- Maximum nesting depth (4 levels)

### Package Age Checker
Prevents installation of outdated npm/yarn packages:
- Blocks packages older than 180 days (configurable)
- Shows latest available versions
- Runs on `npm install` and `yarn add` commands

### Task Completion Notifier
Sends notifications when Claude completes tasks:
- Pushover support for mobile notifications
- macOS native notifications
- Linux desktop notifications

## Configuration

### Hierarchical Configuration

The hook system supports directory-specific configurations:

1. **Root Config**: `.claude/hooks.json` - Default settings for all files
2. **Directory Overrides**: `.claude-hooks.json` files in any directory
3. **Config Inheritance**: Child directories inherit and can override parent settings

Example structure:
```
project/
├── .claude/
│   └── hooks.json          # Root configuration
├── backend/
│   └── .claude-hooks.json  # Stricter rules for backend
└── frontend/
    └── .claude-hooks.json  # Different rules for frontend
```

#### Hook Introspection

See which hooks apply to your files:
```bash
# List all hooks in the project
python3 hooks/list_hooks.py list

# Show effective hooks for a specific file
python3 hooks/list_hooks.py explain path/to/file.py
```

### Environment Variables
- `MAX_AGE_DAYS` - Maximum age for packages (default: 180)
- `CLAUDE_HOOKS_TEST_MODE` - Enable test mode
- `PUSHOVER_USER_KEY` - Your Pushover user key
- `PUSHOVER_APP_TOKEN` - Your Pushover app token

### Pushover Setup
1. Get the Pushover app ($5 one-time): https://pushover.net/clients
2. Create an app at: https://pushover.net/apps/build
3. Add to your `.env` file:
```
PUSHOVER_USER_KEY=your_user_key
PUSHOVER_APP_TOKEN=your_app_token
```

## Hook Architecture

The system uses a dispatcher pattern:
- `universal-*.py` - Main dispatchers that route to specific hooks
- Individual hook files handle specific functionality
- All hooks use JSON for input/output communication

## Development

### Adding New Hooks
1. Create a new Python script in `hooks/`
2. Read JSON input from stdin
3. Output JSON response with `action` field
4. Register in the appropriate universal dispatcher

### Testing Hooks
```bash
# Test with sample input
echo '{"tool_name": "Write", "file_path": "test.py"}' | python3 hooks/post-tool-hook.py

# Enable test mode
export CLAUDE_HOOKS_TEST_MODE=1
```

## License

MIT License - See LICENSE file for details