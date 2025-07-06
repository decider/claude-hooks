# Claude Hooks

A comprehensive set of hooks for [Claude Code](https://claude.ai/code) to enforce clean code practices, prevent outdated dependencies, and automate development workflows.

## 🚀 Features

- **📦 Package Age Validation**: Prevents installation of outdated npm/yarn packages
- **✨ Clean Code Quality System**: Validates function length, complexity, and code smells
- **🔍 Code Similarity Detection**: Prevents code duplication
- **📝 CLAUDE.md Context Updater**: Automatically maintains project documentation
- **🔔 Task Completion Notifications**: System notifications for completed tasks
- **🧪 Comprehensive Testing**: Full test suite for all hooks

## 📥 Installation

### Quick Start (User-Level)

```bash
# Clone the repository
git clone https://github.com/decider/claude-hooks.git
cd claude-hooks

# Run the setup script
./scripts/install.sh
```

### Manual Installation

```bash
# Copy hooks to your Claude directory
cp -r hooks ./claude/hooks
cp config/settings.example.json ./claude/settings.json
chmod +x ./claude/hooks/*.sh
```

### Project Integration

For team projects, see [Integration Guide](docs/INTEGRATION.md) for:
- Vendoring approach (recommended)
- Git submodule setup
- Direct installation

## 📚 Documentation

- [Complete Hook Guide](docs/README.md)
- [Clean Code Principles](docs/CLEAN-CODE-GUIDE.md)
- [Testing Documentation](docs/README-tests.md)
- [Project Integration](docs/INTEGRATION.md)

## ⚙️ Configuration

Edit `./claude/settings.json` to customize:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "./claude/hooks/code-quality-primer.sh"
          }
        ]
      }
    ]
  }
}
```

### Environment Variables

```bash
export MAX_AGE_DAYS=180              # Package age limit
export ENABLE_NOTIFICATIONS=true     # Desktop notifications
export STRICT_MODE=false            # Strict quality checks
```

## 🔧 Available Hooks

| Hook | Description | Trigger |
|------|-------------|---------|
| `check-package-age.sh` | Validates npm/yarn package age | Before package installation |
| `code-quality-primer.sh` | Clean Code reminders | Before file write/edit |
| `code-quality-validator.sh` | Validates code quality | After file write/edit |
| `code-similarity-check.sh` | Detects duplicate code | Before file operations |
| `task-completion-notify.sh` | Desktop notifications | After task completion |
| `pre-commit-check.sh` | Runs tests/lints | Before git commit |
| `claude-context-updater.sh` | Updates CLAUDE.md files | Various triggers |

## 📊 Logging

All hooks automatically log their execution for debugging and monitoring. **Logging is enabled by default** - no configuration needed!

### Default Settings

- **Location**: `./claude/logs/hooks.log`
- **Level**: `INFO` (shows general execution flow)
- **Max Size**: 10MB (auto-rotates when exceeded)
- **Retention**: 7 days (old logs are automatically cleaned up)

### Customizing or Disabling Logging

To customize logging or turn it off, add to your `settings.json`:

```json
{
  "logging": {
    "enabled": false,      // Set to false to disable logging
    "level": "DEBUG",      // Or "WARN", "ERROR" 
    "path": "./custom/path/hooks.log",
    "maxSize": 5242880,    // 5MB in bytes
    "retention": 30        // Keep logs for 30 days
  }
}
```

### Log Levels

- `DEBUG`: Detailed information including inputs/outputs
- `INFO`: General information about hook execution
- `WARN`: Warnings about potential issues
- `ERROR`: Error conditions

### Log Management Tools

```bash
# View logs interactively
./claude/tools/view-logs.sh

# Clean old logs
./claude/tools/clean-logs.sh
```

### Log Format

```
[2025-01-07 10:23:45] [INFO] [check-package-age] Hook started
[2025-01-07 10:23:45] [WARN] [check-package-age] Package lodash@3.10.1 is 2835 days old (limit: 180)
[2025-01-07 10:23:45] [INFO] [check-package-age] Hook completed with exit code 1
```

## 🔄 Updating

To get the latest hooks:

```bash
cd ~/claude-hooks
git pull
./scripts/update.sh
```

## 🧪 Testing

Run the test suite:

```bash
cd tests
./test-all-hooks.sh
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-hook`)
3. Add your hook to `hooks/`
4. Update `config/settings.example.json`
5. Add tests to `tests/`
6. Submit a Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

## 🌟 Support

- Report issues: [GitHub Issues](https://github.com/decider/claude-hooks/issues)
- Documentation: [Wiki](https://github.com/decider/claude-hooks/wiki)
- Discussions: [GitHub Discussions](https://github.com/decider/claude-hooks/discussions)

## 🏷️ Version

Current version: 1.0.0

---

Made with ❤️ for the Claude Code community