# Claude Code Hooks Collection

A comprehensive TypeScript-based set of hooks designed to improve code quality and developer experience when using Claude Code.

## 🎯 Modern TypeScript Architecture

Claude Hooks are now built with TypeScript and modern tooling:
- ✅ **TypeScript-powered** - Full type safety and modern JavaScript features
- ✅ **NPM package** - Install via `npm install -D claude-code-hooks-cli`
- ✅ **Interactive CLI** - Modern command-line interface with prompts
- ✅ **Project-local config** - Uses `claude/` directory structure
- ✅ **Automatic logging** - All executions logged to `./claude/logs/hooks.log`
- ✅ **Smart defaults** - Package validation, code quality checks pre-configured

**Installation is now a single npm command followed by `npx claude-code-hooks-cli init`.**

## Quick Start

### NPM Installation (Recommended)
Install as a development dependency:
```bash
npm install -D claude-code-hooks-cli
npx claude-code-hooks-cli init
```

### Legacy Installation Methods
These methods are still supported but not recommended:

#### Option 1: User-Level Installation
```bash
# Clone the repository
git clone https://github.com/your-org/claude-hooks.git
cd claude-hooks

# Run the installation script
./scripts/install.sh
```

#### Option 2: Project-Level Installation
```bash
# In your project directory
./path/to/claude-hooks/scripts/install-project.sh
```

#### Option 3: Manual Installation
```bash
# Copy hooks to your Claude directory
cp -r hooks ./claude/hooks
cp config/settings.example.json ./claude/settings.json
chmod +x ./claude/hooks/*.sh
```

## Installation Methods

### NPM Package (Recommended)
- **Command**: `npm install -D claude-code-hooks-cli`
- **Location**: Runs from `node_modules/`, config in `claude/settings.json`
- **Scope**: Per-project via package.json
- **Setup**: Run `npx claude-code-hooks-cli init`
- **Customization**: Interactive CLI or edit `claude/settings.json`
- **Benefits**: Version-locked, always up-to-date, TypeScript-powered

### Legacy Methods (Still Supported)

#### User-Level Hooks
- **Location**: `./claude/hooks/` and `./claude/settings.json`
- **Scope**: Apply to all your projects
- **Setup**: Run `./scripts/install.sh`
- **Customization**: Edit `./claude/settings.json` directly

#### Project-Level Hooks (Team Use)
- **Location**: `project/claude/hooks/` and `project/claude/settings.json`
- **Scope**: Apply to all team members automatically
- **Setup**: Use git submodule via `./scripts/install-project.sh`
- **Customization**: Edit project-specific settings

## Available Hooks

### 1. Package Age Validator (`check-package-age.sh`)
**Purpose**: Prevents installation of outdated npm/yarn packages

**Features**:
- Blocks packages older than 6 months (configurable)
- Suggests latest versions
- Works with npm and yarn

**Configuration**:
```bash
export MAX_AGE_DAYS=180  # Default: 180 days
```

### 2. Code Quality Primer (`code-quality-primer.sh`)
**Purpose**: Pre-write hook that promotes Clean Code principles

**Features**:
- Injects language-specific Clean Code reminders
- Checks for existing similar functions
- Suggests utilities from common libraries
- Prevents code duplication

**Triggers**: Before Write/Edit/MultiEdit operations

### 3. Code Quality Validator (`code-quality-validator.sh`)
**Purpose**: Post-write hook that validates code against Clean Code rules

**Validates**:
- Function length (max 20 lines)
- File length (max 100 lines, 150 for components)
- Nesting depth (max 3 levels)
- Line length (max 80 characters)
- Magic numbers
- Comment ratio
- Code duplication patterns

**Triggers**: After Write/Edit/MultiEdit operations

### 4. Code Similarity Checker (`code-similarity-check.sh`)
**Purpose**: Utility to detect similar code patterns

**Features**:
- Pattern detection for common implementations
- Suggests library alternatives
- Calculates similarity scores

**Usage**:
```bash
./claude/hooks/code-similarity-check.sh "function content" ts
```

### 5. Task Completion Notifier (`task-completion-notify.sh`)
**Purpose**: Sends system notifications for completed tasks

**Notifications for**:
- File operations (create/update/delete)
- Git operations (commit/push)
- Build/test completions
- Todo completions
- Session completion

**Platform Support**:
- macOS: Native notifications with sound
- Linux: notify-send notifications
- Other: Terminal bell

### 6. Code Index Builder (`build-code-index.sh`)
**Purpose**: Creates searchable index of codebase

**Indexes**:
- Exported functions with locations
- React components
- Custom hooks
- TypeScript types and interfaces
- Utility directories

**Usage**:
```bash
./claude/hooks/build-code-index.sh  # Full index (slower)
./claude/hooks/quick-index.sh       # Quick statistics
```

### 8. Claude Context Updater (`claude-context-updater.sh`)
**Purpose**: Automatically maintains CLAUDE.md files based on code changes

**Features**:
- Runs when Claude Code session ends
- Detects directories needing CLAUDE.md files
- Suggests updates to existing CLAUDE.md files
- Tracks package.json, config, and structural changes
- Creates review proposals in `.claude-updates/`

**Configuration**:
```bash
export ENABLE_CONTEXT_UPDATER=true      # Enable/disable hook
export AUTO_CREATE_CLAUDE_MD=true       # Create new CLAUDE.md files
export UPDATE_EXISTING_CLAUDE_MD=true   # Update existing files
export CLAUDE_UPDATES_DIR=.claude-updates # Proposal directory
```

**Triggers**: When Claude Code stops/exits

**Review Process**:
1. Check `.claude-updates/session_*/` for proposals
2. Review CREATE_* files for new CLAUDE.md suggestions
3. Review UPDATE_* files for update suggestions
4. Apply changes manually as appropriate

## Configuration Files

### clean-code-rules.json
Customizable thresholds and rules:
```json
{
  "rules": {
    "maxFunctionLines": 20,
    "maxFileLines": 100,
    "maxNestingDepth": 3,
    "maxParameters": 3
  }
}
```

### settings.example.json
Example Claude settings with all hooks configured.

## Customization

### For NPM Package (Recommended)
1. **Interactive CLI**: Run `npx claude-code-hooks-cli manage`
2. **Edit Settings**: Modify `claude/settings.json` directly
3. **Custom Rules**: Edit `claude/hooks/clean-code-rules.json`
4. **Remove Hooks**: Use CLI manager or comment out hook entries
5. **Environment Variables**: Set variables like `ENABLE_CODE_QUALITY_VALIDATOR=false`

### For Legacy Installations

#### User-Level Hooks
1. **Edit Settings**: Modify `./claude/settings.json` directly
2. **Custom Rules**: Edit `./claude/hooks/clean-code-rules.json`
3. **Remove Hooks**: Comment out or delete hook entries in your settings.json
4. **Environment Variables**: Set variables like `ENABLE_CODE_QUALITY_VALIDATOR=false`

#### Project-Level Hooks
1. **Edit Project Settings**: Modify `project/claude/settings.json`
2. **Custom Rules**: Edit `project/claude/hooks/clean-code-rules.json` (affects all team members)
3. **Environment Variables**: Set in project environment or CI/CD

### Disabling Hooks
To temporarily disable hooks:
1. **All hooks**: Rename or remove settings.json file
2. **Specific hooks**: Set environment variables like `ENABLE_PACKAGE_AGE_CHECK=false`
3. **Per-project**: Override in project-specific settings

### Adding Custom Patterns
Edit similarity checker to add project-specific patterns.

## Troubleshooting

### Hooks Not Triggering
1. **NPM Package**: Verify `claude/settings.json` exists and contains `npx claude-code-hooks-cli exec` commands
2. **Legacy**: Verify `./claude/settings.json` exists
3. **Legacy**: Check hook paths are correct
4. **Legacy**: Ensure hooks are executable: `chmod +x ./claude/hooks/*.sh`
5. **All**: Run `npx claude-code-hooks-cli list` to verify package installation

### Performance Issues
- Use `quick-index.sh` instead of full indexer
- Adjust validation rules to be less strict
- Disable real-time validation for large files

### False Positives
- Customize rules in `clean-code-rules.json`
- Add exceptions for specific patterns
- Use environment variables to override defaults

## Best Practices

1. **Run indexer regularly**: Keep code index up to date
2. **Review suggestions**: Don't blindly follow all recommendations
3. **Customize for your project**: Adjust rules to match team standards
4. **Share configurations**: Commit custom rules to the repository

## Contributing

To add new hooks:
1. **TypeScript**: Create hook command in `src/commands/`
2. **Legacy**: Create hook script in `hooks/` directory
3. Add to `settings.example.json`
4. Update setup script and CLI
5. Document in this README
6. Run `npm run build` to compile TypeScript

## Resources

- [Clean Code book](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882) by Robert C. Martin
- [SOLID principles](https://en.wikipedia.org/wiki/SOLID)
- [DRY principle](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)