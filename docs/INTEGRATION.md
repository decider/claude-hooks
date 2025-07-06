# Integrating Claude Hooks into Your Project

There are several ways to integrate Claude Hooks into your project:

## Option 1: User-Level Installation (Recommended for Individual Developers)

Install hooks globally in your home directory:

```bash
git clone https://github.com/your-org/claude-hooks.git ~/claude-hooks
cd ~/claude-hooks
./scripts/install.sh
```

The hooks will apply to all your projects automatically.

## Option 2: Project-Level Integration (For Teams)

### Method A: Copy Hooks Directly

1. Clone the claude-hooks repository somewhere on your machine:
   ```bash
   git clone https://github.com/your-org/claude-hooks.git ~/claude-hooks
   ```

2. In your project, create an installation script:
   ```bash
   #!/bin/bash
   CLAUDE_HOOKS_REPO="$HOME/claude-hooks"
   
   # Copy hooks to project
   cp -r "$CLAUDE_HOOKS_REPO/hooks" ./claude/
   cp "$CLAUDE_HOOKS_REPO/config/settings.example.json" ./claude/settings.json
   chmod +x ./claude/hooks/*.sh
   ```

3. Commit the claude directory to your project
4. Team members run the project's setup script

### Method B: Git Submodule

1. Add claude-hooks as a submodule:
   ```bash
   git submodule add https://github.com/your-org/claude-hooks.git claude-hooks
   ```

2. Copy hooks to your project:
   ```bash
   cp -r claude-hooks/hooks claude/
   cp claude-hooks/config/settings.example.json claude/settings.json
   ```

3. Create a setup script for team members:
   ```bash
   ./claude-hooks/scripts/install-project.sh
   ```

### Method C: NPM/Yarn Package (Future)

Once published as an npm package:
```bash
npm install --save-dev @your-org/claude-hooks
npx claude-hooks install
```

## Keeping Hooks Updated

### For User-Level Installation
```bash
cd ~/claude-hooks
git pull
./scripts/update.sh
```

### For Project-Level Integration
```bash
# Update from external repo
cd ~/claude-hooks && git pull
cd /path/to/your/project
./claude/install-from-external.sh
```

### For Submodule Integration
```bash
git submodule update --remote claude-hooks
cp -r claude-hooks/hooks/* claude/hooks/
```

## Configuration

After installation, customize the hooks by editing:
- **User-level**: `~/.claude/settings.json`
- **Project-level**: `./claude/settings.json`

See [Configuration Guide](README.md#configuration) for details.