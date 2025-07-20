# Migration Guide: CLI to Python Hooks

This guide helps users transition from the previous npm-based CLI version to the new Python-based hook system.

## What Changed?

The claude-hooks project has been completely rewritten from a TypeScript/Node.js CLI tool to a lightweight Python-based system. This change brings:

- **No dependencies** - Pure Python, no npm or node_modules
- **Simpler installation** - Just run one Python script
- **Better portability** - Works on any system with Python 3
- **Easier customization** - Edit Python files directly

## Migration Steps

### 1. Uninstall the Old CLI

If you have the npm package installed globally:
```bash
npm uninstall -g claude-code-hooks-cli
```

If installed locally in your project:
```bash
npm uninstall claude-code-hooks-cli
```

### 2. Clean Up Old Files

Remove any old configuration or dependencies:
```bash
# Remove old node_modules if present
rm -rf node_modules

# Remove package-lock.json if it only contained claude-hooks
rm package-lock.json
```

### 3. Install the New System

Run the Python installer:
```bash
python3 install-hooks.py
```

This creates the same `.claude/` directory structure but with Python hooks instead.

### 4. Update Your Workflow

#### Before (CLI Commands):
```bash
claude-hooks init          # Initialize hooks
claude-hooks manage        # Manage hooks interactively
claude-hooks list          # List available hooks
claude-hooks validate      # Validate configuration
```

#### After (Direct Installation):
```bash
python3 install-hooks.py   # One-time setup
# Edit .claude/hooks/*.py files directly for customization
```

## Feature Comparison

| Feature | Old CLI Version | New Python Version |
|---------|----------------|-------------------|
| Installation | `npm install -g` | `python3 install-hooks.py` |
| Dependencies | Node.js, npm, TypeScript | Python 3 only |
| Configuration | Interactive CLI | Direct file editing |
| Hook Discovery | `.claude/hooks.json` | Built into Python files |
| Custom Hooks | CLI commands | Edit Python files |
| Updates | `npm update` | Copy new files |

## Customization

### Old Way (CLI):
- Use `claude-hooks manage` to select hooks
- Create `.claude/hooks.json` for project hooks
- Use CLI commands to add/remove hooks

### New Way (Python):
- Edit `.claude/settings.json` directly
- Modify Python files in `.claude/hooks/`
- Add custom logic to universal hook files

## Common Questions

### Q: Why was the CLI removed?
A: The Python implementation is simpler, has no dependencies, and provides the same functionality with less complexity.

### Q: Will my old hooks still work?
A: The core hooks (code quality, package age, notifications) work exactly the same. You just can't manage them through a CLI anymore.

### Q: How do I add custom validation?
A: Edit the universal hook files (e.g., `universal-pre-tool.py`) and add your logic directly in Python.

### Q: Can I still share hooks with my team?
A: Yes! The `.claude/` directory is designed to be committed to version control.

## Need Help?

If you encounter issues during migration:
1. Ensure Python 3 is installed: `python3 --version`
2. Check that the installer ran successfully
3. Verify `.claude/settings.json` was created
4. Test hooks are working in Claude Code

The new system is designed to be simpler and more reliable than the CLI version while providing the same protection and validation features.