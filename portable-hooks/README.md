# Portable Code Quality Hooks for Claude

Lightweight, dependency-free code quality hooks that work with any language.

## Features

- **No dependencies** - Pure bash, no Node.js or npm required
- **Multi-language support** - TypeScript, JavaScript, Python, Ruby, and more
- **Automatic enforcement** - Blocks bad code before and after writing
- **Simple installation** - One script to set up everything

## Quick Install

```bash
# Clone just the portable hooks
git clone https://github.com/yourusername/claude-hooks
cd claude-hooks
./install-hooks.sh
```

Or copy these files to your project:
```
hooks/
├── stop-hook.sh              # Runs on Stop events
├── post-tool-hook.sh         # Runs after Write/Edit
├── pre-tool-hook.sh          # Runs before Write/Edit
└── portable-quality-validator.sh  # Main validator

.claude/
├── settings.json             # Hook configuration
└── hooks/
    └── quality-config.json   # Quality rules
```

## Configuration

Edit `.claude/hooks/quality-config.json`:

```json
{
  "rules": {
    "maxFunctionLines": 30,
    "maxFileLines": 200,
    "maxLineLength": 100,
    "maxNestingDepth": 4
  }
}
```

## Supported Languages

### TypeScript/JavaScript
- Function length limits
- Nesting depth checks
- Line length validation

### Python
- PEP8 indentation (4 spaces)
- Function/class length
- Line length validation

### Ruby
- Ruby style indentation (2 spaces)
- Method length limits
- Line length validation

## How It Works

1. **PreToolUse** - Analyzes code before Claude writes it
2. **PostToolUse** - Validates files after changes
3. **Stop** - Ensures clean code before ending session

## Adding to Existing Projects

1. Copy the `hooks/` directory to your project
2. Run `./install-hooks.sh`
3. Customize `.claude/hooks/quality-config.json`

## Customization

Add new languages by editing the validators:

```bash
# In portable-quality-validator.sh
check_golang() {
    local file="$1"
    # Add Go-specific checks
}
```

## No Node.js Required

Unlike the full claude-hooks system, this portable version:
- Uses only bash and standard Unix tools
- Works in Python, Ruby, Go, and other projects
- Has zero npm dependencies
- Installs in seconds

## License

MIT