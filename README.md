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
- Maximum function length (50 lines)
- Maximum file length (300 lines)
- Maximum nesting depth (4 levels)
- Cyclomatic complexity limits

### Package Age Checker
Prevents installation of severely outdated npm/yarn packages:
- Blocks packages older than 5 years
- Warns for packages older than 3 years
- Provides helpful suggestions for alternatives

### Task Completion Notifier
Sends system notifications when Claude completes tasks (optional).

## Configuration

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "python3 .claude/hooks/universal-pre-tool.py"
      }]
    }],
    "PostToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "python3 .claude/hooks/universal-post-tool.py"
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "python3 .claude/hooks/universal-stop.py"
      }]
    }]
  }
}
```

## Writing Custom Hooks

To add custom validation logic, edit the universal hook files in `.claude/hooks/`:

```python
# Example: Add custom validation to universal-pre-tool.py
def handle_pre_tool_event(data):
    tool_name = data.get('tool_name', '')
    
    if tool_name == 'Bash':
        command = data.get('tool_input', {}).get('command', '')
        # Add your custom logic here
        if 'dangerous_command' in command:
            print("❌ Blocked: This command is not allowed")
            sys.exit(1)
```

## Project Structure

```
.claude/
├── settings.json         # Hook configuration
├── settings.local.json   # Personal settings (git ignored)
└── hooks/
    ├── universal-pre-tool.py
    ├── universal-post-tool.py
    ├── universal-stop.py
    ├── check_package_age.py
    ├── code_quality_validator.py
    └── validators.py
```

## Migration from CLI Version

If you were using the previous npm-based CLI version:
1. Uninstall the old package: `npm uninstall -g claude-code-hooks-cli`
2. Run the new installer: `python3 install-hooks.py`
3. Your hooks will work the same way, just without the CLI commands

## Benefits

✅ **No dependencies** - Pure Python, no npm or node_modules required  
✅ **Portable** - Works on any system with Python 3  
✅ **Simple** - Direct integration, no complex CLI needed  
✅ **Lightweight** - Minimal footprint in your project  
✅ **Version control friendly** - Easy to customize and commit  

## Development

To modify or extend hooks:
1. Edit the Python files in `.claude/hooks/`
2. Test your changes - hooks run automatically in Claude Code
3. Commit your customizations to share with your team

## Contributing

Contributions are welcome! This project uses Python for simplicity and portability.

## License

MIT