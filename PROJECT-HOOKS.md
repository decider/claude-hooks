# Project-Level Claude Code Hooks Setup

This guide explains how to set up Claude Code hooks at the project level, making them work automatically for all team members.

## How It Works

When Claude Code hooks are configured at the project level, they are automatically applied when team members use Claude Code. These hooks can:

1. **Validate package age** before installing npm packages
2. **Remind about Clean Code principles** before writing code
3. **Validate code quality** after writing/editing files
4. **Run lints and tests** before marking tasks complete or committing
5. **Send notifications** for completed tasks

## Setup for Teams

To enable project-level hooks in your repository:

1. **Install as submodule**:
   ```bash
   git submodule add https://github.com/your-org/claude-hooks.git claude-hooks
   ```

2. **Copy hooks to project**:
   ```bash
   cp -r claude-hooks/hooks claude/
   cp claude-hooks/config/settings.example.json claude/settings.json
   ```

3. **Customize for your project**:
   Edit `claude/settings.json` to match your team's needs

4. **Commit the changes**:
   ```bash
   git add claude/ claude-hooks/
   git commit -m "Add Claude Code hooks for team"
   ```

## Team Member Setup

Team members need to run once after cloning:
```bash
./claude/setup-hooks.sh
```

## Customization

### Personal Preferences
Individual team members can customize hook behavior using environment variables:

```bash
# In your shell profile (.bashrc, .zshrc, etc.)
export MAX_AGE_DAYS=365                    # Allow older packages
export ENABLE_CODE_QUALITY_VALIDATOR=false # Disable specific hooks
export STRICT_MODE=false                   # Disable strict mode
export ENABLE_NOTIFICATIONS=true           # Enable desktop notifications
```

### Project-Wide Customization
Edit the project's hook configuration:

1. **Hook Settings**: Modify `claude/settings.json`
2. **Clean Code Rules**: Edit `claude/hooks/clean-code-rules.json`
3. **Context Rules**: Edit `claude/hooks/claude-context-rules.json`

### Temporarily Disable All Hooks
If you need to disable project hooks temporarily:
- Rename `claude/settings.json` to `claude/settings.json.disabled`
- When done, rename it back

## Hook Details

### 1. Package Age Validator
- **Trigger**: When running `npm install` or `yarn add`
- **Purpose**: Prevents installing outdated packages
- **Config**: `MAX_AGE_DAYS` (default: 180)

### 2. Clean Code Primer
- **Trigger**: Before Write/Edit/MultiEdit operations
- **Purpose**: Reminds about code quality principles
- **Config**: `ENABLE_CODE_QUALITY_PRIMER`

### 3. Clean Code Validator  
- **Trigger**: After Write/Edit/MultiEdit operations
- **Purpose**: Validates function length, complexity, etc.
- **Config**: Edit `.claude/hooks/clean-code-rules.json`

### 4. Pre-Completion Quality Check
- **Trigger**: Before marking tasks complete or committing
- **Purpose**: Runs TypeScript, ESLint, and tests
- **Config**: `STRICT_MODE`, `RUN_TESTS`, `RUN_LINT`, `RUN_TYPECHECK`

### 5. Task Notifications
- **Trigger**: After various operations
- **Purpose**: Desktop notifications for completed tasks
- **Config**: `ENABLE_NOTIFICATIONS`, `NOTIFICATION_SOUND`

## Troubleshooting

### Hooks Not Working?
1. Ensure you're using the latest version of Claude Code
2. Check that `claude/settings.json` exists in the project
3. Verify hook scripts are executable: `ls -la ~/.claude/hooks/*.sh`
4. Run the setup script: `./claude/setup-hooks.sh`

### Want User-Level Hooks Instead?
Install hooks globally using the standalone repository:
```bash
git clone https://github.com/your-org/claude-hooks.git
cd claude-hooks
./scripts/install.sh
```

### Need Help?
- See `docs/README.md` for detailed documentation
- Check `config/settings.example.json` for all configuration options
- Review individual hook documentation in `docs/`