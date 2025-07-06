# Claude Hooks

A comprehensive set of hooks for Claude Code to enforce clean code practices, prevent outdated dependencies, and automate development workflows.

## Features

- **Package Age Validation**: Prevents installation of outdated npm/yarn packages
- **Clean Code Quality System**: Validates function length, complexity, and code smells
- **Code Similarity Detection**: Prevents code duplication
- **CLAUDE.md Context Updater**: Automatically maintains project documentation
- **Task Completion Notifications**: System notifications for completed tasks
- **Comprehensive Testing**: Full test suite for all hooks

## Quick Start

```bash
# Clone the repository
git clone https://github.com/your-org/claude-hooks.git

# Run the setup script
./scripts/install.sh

# Or install manually
cp -r hooks ~/.claude/hooks
cp config/settings.example.json ~/.claude/settings.json
chmod +x ~/.claude/hooks/*.sh
```

## Documentation

- [Installation Guide](docs/README.md)
- [Clean Code Guide](docs/CLEAN-CODE-GUIDE.md)
- [Testing Guide](docs/README-tests.md)

## Configuration

Edit `~/.claude/settings.json` to customize:
- Package age limits
- Clean code rules
- Notification settings
- Hook enable/disable

## Version

Current version: 1.0.0

## License

MIT