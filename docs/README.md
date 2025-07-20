# Claude Code Hooks Documentation

Documentation and guides for the Claude Code Hooks system.

## Overview

Claude Code Hooks is a Python-based validation system that provides automatic quality checks and validation for Claude Code sessions. The system uses lightweight Python scripts that integrate directly with Claude's hook events.

## Documentation Structure

- **[CLEAN-CODE-GUIDE.md](CLEAN-CODE-GUIDE.md)** - Best practices for clean code
- **[ideas-for-hooks/](ideas-for-hooks/)** - Ideas and proposals for future hooks
- **[../MIGRATION.md](../MIGRATION.md)** - Guide for migrating from the old CLI version

## Hook System Architecture

The hook system uses three main entry points:
- **PreToolUse** - Validates operations before execution
- **PostToolUse** - Checks results after operations complete
- **Stop** - Runs when Claude stops or completes tasks

## Available Hooks

### Code Quality Validator
Enforces clean code standards on file edits:
- Maximum function length (50 lines)
- Maximum file length (300 lines)
- Maximum nesting depth (4 levels)
- Cyclomatic complexity limits

### Package Age Checker
Prevents installation of outdated npm/yarn packages:
- Blocks packages older than 5 years
- Warns for packages older than 3 years
- Suggests modern alternatives

### Task Completion Notifier
Optional system notifications when Claude completes tasks.

## Writing Custom Hooks

Hooks are Python scripts that receive event data via stdin and can:
1. Validate conditions
2. Provide warnings or suggestions
3. Block operations if needed
4. Send notifications

Example hook structure:
```python
import json
import sys

# Read event data
data = json.loads(sys.stdin.read())

# Process based on event type
if data.get('tool_name') == 'Bash':
    command = data.get('tool_input', {}).get('command', '')
    # Add validation logic here
```

## Best Practices

1. **Keep hooks fast** - They run synchronously during Claude operations
2. **Provide helpful feedback** - Clear messages help users understand issues
3. **Use warnings before blocking** - Allow users to understand and fix issues
4. **Log for debugging** - But avoid excessive output

## Contributing

To contribute new hooks or improvements:
1. Create Python scripts following the existing patterns
2. Test thoroughly with various inputs
3. Document the hook's purpose and configuration
4. Submit a pull request with examples

## Resources

- [Clean Code principles](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Python best practices](https://docs.python-guide.org/)
- [Claude Code documentation](https://claude.ai/code)