# Claude Hooks NPM Package Implementation Plan

## Overview
Transform claude-hooks into an NPM package with CLI for seamless hook management across projects, supporting multiple installation levels and execution modes.

## Verification
✅ **Confirmed**: NPX/npm commands work in Claude hooks (tested with node v23.11.0, npm 11.4.2)

## Phase 1: NPM Package Structure

### 1.1 Create Package Foundation
```
claude-hooks/
├── package.json                 # NPM package manifest
├── bin/
│   └── claude-hooks.js         # CLI entry point (#!/usr/bin/env node)
├── lib/
│   ├── cli.js                  # Main CLI logic
│   ├── commands/
│   │   ├── init.js             # Initialize hooks
│   │   ├── add.js              # Add hooks
│   │   ├── remove.js           # Remove hooks
│   │   ├── list.js             # List hooks
│   │   ├── update.js           # Update hooks
│   │   ├── sync.js             # Sync all hooks
│   │   ├── exec.js             # Execute hook (for npx mode)
│   │   └── validate.js         # Validate configuration
│   ├── config/
│   │   ├── settings-manager.js  # Handle settings.json CRUD
│   │   ├── path-resolver.js     # Resolve paths for different levels
│   │   └── format-migrator.js   # Migrate old to new format
│   └── utils/
│       ├── hook-installer.js    # Copy/symlink hooks
│       ├── version-checker.js   # Check for updates
│       └── logger.js            # CLI output formatting
├── hooks/                       # Hook scripts (unchanged)
├── templates/
│   ├── settings.json           # Template configurations
│   └── presets.json            # Preset bundles
└── test/
    └── ... (tests for all components)
```

### 1.2 Package.json Configuration
```json
{
  "name": "@claude-hooks/cli",
  "version": "1.0.0",
  "description": "CLI for managing Claude Code hooks",
  "bin": {
    "claude-hooks": "./bin/claude-hooks.js"
  },
  "files": [
    "bin/",
    "lib/",
    "hooks/",
    "templates/"
  ],
  "engines": {
    "node": ">=16.0.0"
  },
  "dependencies": {
    "commander": "^11.0.0",
    "inquirer": "^9.0.0",
    "chalk": "^5.0.0",
    "fs-extra": "^11.0.0",
    "semver": "^7.0.0"
  }
}
```

## Phase 2: Core CLI Commands

### 2.1 Init Command
```bash
claude-hooks init [options]
```
- Interactive setup wizard
- Detect existing Claude configuration
- Choose preset or custom selection
- Select installation level(s)

### 2.2 Add Command
```bash
claude-hooks add <hook-name> [options]
  --level <level>     # project-team|project-local|user-global
  --mode <mode>       # copy|symlink|npx
  --force            # Overwrite existing
```

### 2.3 Remove Command
```bash
claude-hooks remove <hook-name> [options]
  --level <level>     # Which configs to remove from
  --keep-files       # Don't delete hook files
  --all              # Remove all hooks
```

### 2.4 List Command
```bash
claude-hooks list [options]
  --available        # Show all available hooks
  --installed        # Show only installed
  --outdated         # Show hooks with updates
```

### 2.5 Exec Command (for NPX mode)
```bash
claude-hooks exec <hook-name>
```
- Executes hook from node_modules
- Handles stdin/stdout properly
- Used in settings.json for npx mode

## Phase 3: Installation Modes

### 3.1 Copy Mode (Default)
- Copies hook files to `./claude/hooks/`
- No dependency on NPM after install
- Settings.json uses relative paths:
  ```json
  {
    "command": "./claude/hooks/stop-validation.sh"
  }
  ```

### 3.2 Symlink Mode
- Creates symlinks from `./claude/hooks/` to `node_modules/`
- Auto-updates when NPM package updates
- Same settings.json as copy mode

### 3.3 NPX Mode
- No local files needed
- Requires @claude-hooks/cli in package.json
- Settings.json uses npx:
  ```json
  {
    "command": "npx @claude-hooks/cli exec stop-validation"
  }
  ```

## Phase 4: Configuration Levels

### 4.1 Path Resolution
- **Project Team**: `./.claude/settings.json` (git tracked)
- **Project Local**: `./.claude/settings.local.json` (git ignored)
- **User Global**: `~/.claude/settings.json`

### 4.2 Settings Manager Features
- Merge configurations without overwriting
- Handle arrays properly (don't duplicate)
- Format validation and migration
- Backup before modifications

## Phase 5: Implementation Steps

### Step 1: Create Basic CLI Structure
1. Set up NPM package structure
2. Implement commander.js CLI framework
3. Create basic command stubs

### Step 2: Implement Core Features
1. Settings manager (read/write/merge)
2. Hook installer (copy/symlink)
3. Format migrator (old → new)
4. Path resolver for different levels

### Step 3: Build Commands
1. Init with interactive prompts
2. Add/remove with options
3. List with filtering
4. Exec for npx mode

### Step 4: Add Advanced Features
1. Version checking and updates
2. Hook dependency resolution
3. Preset bundles
4. Configuration validation

### Step 5: Testing & Documentation
1. Unit tests for all components
2. Integration tests for CLI commands
3. Documentation and examples
4. Migration guide from current setup

## Phase 6: Usage Examples

### First Time Setup
```bash
npm install -D @claude-hooks/cli
npx claude-hooks init

# Interactive:
? Choose installation level: Project (team)
? Select preset: Recommended
? Installation mode: Copy files
✓ Installed 3 hooks
✓ Created .claude/settings.json
```

### Adding Specific Hook
```bash
npx claude-hooks add stop-validation --level project-team
```

### NPX Mode Setup
```bash
npx claude-hooks init --mode npx
# Creates settings.json with npx commands
# No files copied locally
```

### Remove All and Reinstall
```bash
npx claude-hooks remove --all
npx claude-hooks add --all --preset recommended
```

## Phase 7: Migration Strategy

### For Existing Users
1. Detect existing installation
2. Offer to migrate settings
3. Preserve customizations
4. Update format if needed

### Backwards Compatibility
- Support both old and new settings format
- Provide migration command
- Keep existing paths working

## Success Criteria
- [ ] All hooks work in all three modes (copy/symlink/npx)
- [ ] Seamless updates with `npm update`
- [ ] Clear separation of team/local/global configs
- [ ] Interactive CLI for ease of use
- [ ] Zero breaking changes for existing users
- [ ] Comprehensive test coverage

## Next Steps
1. Create basic NPM package structure
2. Implement core settings manager
3. Build CLI commands incrementally
4. Test with real projects
5. Publish to NPM registry