# Legacy Integration Methods

> **Note**: These methods are deprecated. Use the [npm package](./INTEGRATION.md) instead.

## Vendoring Hooks (For Special Cases)

If you need to vendor hooks directly into your project (e.g., for air-gapped environments), you can use the update-vendored.sh script:

### Initial Setup

1. Clone claude-hooks and copy to your project:
   ```bash
   git clone https://github.com/your-org/claude-hooks.git ~/claude-hooks
   cd /path/to/your/project
   cp -r ~/claude-hooks ./claude-hooks
   ```

2. Copy the update script to your project:
   ```bash
   mkdir -p scripts
   cp ~/claude-hooks/scripts/update-vendored.sh scripts/update-claude-hooks.sh
   chmod +x scripts/update-claude-hooks.sh
   ```

3. Create a setup script at `claude/setup-hooks.sh`:
   ```bash
   #!/bin/bash
   # Copy vendored hooks to user's ./claude directory
   cp -r ./claude-hooks/hooks ./claude/
   cp -r ./claude-hooks/tools ./claude/ 2>/dev/null || true
   chmod +x ./claude/hooks/*.sh
   echo "✅ Claude hooks installed from vendored copy!"
   ```

4. Add to your project's README:
   ```markdown
   ## Setup
   Run `./claude/setup-hooks.sh` to install Claude Code hooks.
   ```

### Updating Vendored Hooks

To update the vendored hooks:
```bash
./scripts/update-claude-hooks.sh
git add claude-hooks/
git commit -m "chore: update claude-hooks"
```

## Git Submodule Method

Add claude-hooks as a submodule:
```bash
git submodule add https://github.com/your-org/claude-hooks.git claude-hooks
```

Update submodule:
```bash
git submodule update --remote claude-hooks
cp -r claude-hooks/hooks/* claude/hooks/
```

## Direct Copy Method

1. Clone the claude-hooks repository:
   ```bash
   git clone https://github.com/your-org/claude-hooks.git ~/claude-hooks
   ```

2. Copy hooks to your project:
   ```bash
   cp -r ~/claude-hooks/hooks ./claude/
   cp ~/claude-hooks/config/settings.example.json ./claude/settings.json
   chmod +x ./claude/hooks/*.sh
   ```

3. Commit the claude directory to your project

## Why Use the NPM Package Instead?

- **Easier updates**: Just run `npm update`
- **Version management**: Lock to specific versions in package.json
- **No manual copying**: Everything is handled automatically
- **Better tooling**: Interactive CLI, validation, and more
- **Team consistency**: Everyone gets the same version