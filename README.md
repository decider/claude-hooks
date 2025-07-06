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
git clone https://github.com/your-org/claude-hooks.git
cd claude-hooks

# Run the setup script
./scripts/install.sh
```

### Manual Installation

```bash
# Copy hooks to your Claude directory
cp -r hooks ~/.claude/hooks
cp config/settings.example.json ~/.claude/settings.json
chmod +x ~/.claude/hooks/*.sh
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

Edit `~/.claude/settings.json` to customize:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/code-quality-primer.sh"
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

- Report issues: [GitHub Issues](https://github.com/your-org/claude-hooks/issues)
- Documentation: [Wiki](https://github.com/your-org/claude-hooks/wiki)
- Discussions: [GitHub Discussions](https://github.com/your-org/claude-hooks/discussions)

## 🏷️ Version

Current version: 1.0.0

---

Made with ❤️ for the Claude Code community