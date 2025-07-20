#!/bin/bash

# Portable Code Quality Hooks Installer
# Installs Claude hooks without Node.js dependencies

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Claude Code Quality Hooks Installer${NC}"
echo "===================================="
echo

# Check if we're in a git repository
if [[ ! -d .git ]]; then
    echo -e "${YELLOW}Warning: Not in a git repository root${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create .claude directory structure
echo "Creating .claude directory structure..."
mkdir -p .claude/hooks

# Copy hook files
echo "Copying hook files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create minimal hooks directory
mkdir -p hooks/common/code-quality/checks

# Copy only essential files
cp "$SCRIPT_DIR/hooks/portable-quality-validator.sh" hooks/
cp "$SCRIPT_DIR/hooks/stop-hook.sh" hooks/
cp "$SCRIPT_DIR/hooks/post-tool-hook.sh" hooks/
cp "$SCRIPT_DIR/hooks/pre-tool-hook.sh" hooks/

# Copy quality checks if they exist
if [[ -d "$SCRIPT_DIR/hooks/common/code-quality/checks" ]]; then
    cp "$SCRIPT_DIR/hooks/common/code-quality/loader.sh" hooks/common/code-quality/
    cp "$SCRIPT_DIR/hooks/common/code-quality/checks/"*.sh hooks/common/code-quality/checks/ 2>/dev/null || true
fi

# Make all hooks executable
chmod +x hooks/*.sh
chmod +x hooks/common/code-quality/*.sh 2>/dev/null || true
chmod +x hooks/common/code-quality/checks/*.sh 2>/dev/null || true

# Create quality configuration
echo "Creating quality configuration..."
cat > .claude/hooks/quality-config.json << 'EOF'
{
  "rules": {
    "maxFunctionLines": 30,
    "maxFileLines": 200,
    "maxLineLength": 100,
    "maxNestingDepth": 4,
    "commentRatioThreshold": 10
  },
  "ignore": {
    "paths": [
      "node_modules/**",
      "vendor/**",
      "lib/**",
      "dist/**",
      "build/**",
      "coverage/**",
      ".git/**"
    ],
    "files": [
      "*.d.ts",
      "*.min.js",
      "*.map",
      "*-lock.json",
      "*.lock"
    ]
  }
}
EOF

# Create settings.json with direct bash hooks
echo "Creating Claude settings..."
cat > .claude/settings.json << 'EOF'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash hooks/stop-hook.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash hooks/pre-tool-hook.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash hooks/post-tool-hook.sh"
          }
        ]
      }
    ]
  }
}
EOF

# Add to .gitignore
echo "Updating .gitignore..."
if [[ -f .gitignore ]]; then
    # Check if already ignored
    if ! grep -q "^\.claude/hooks/\*\.log" .gitignore; then
        echo "" >> .gitignore
        echo "# Claude hook logs" >> .gitignore
        echo ".claude/hooks/*.log" >> .gitignore
    fi
else
    cat > .gitignore << 'EOF'
# Claude hook logs
.claude/hooks/*.log
EOF
fi

echo
echo -e "${GREEN}✓ Installation complete!${NC}"
echo
echo "The following hooks are now active:"
echo "  • PreToolUse  - Checks code quality before writing"
echo "  • PostToolUse - Verifies code quality after changes"
echo "  • Stop        - Ensures clean code before ending session"
echo
echo "Supported languages:"
echo "  • TypeScript/JavaScript (.ts, .tsx, .js, .jsx)"
echo "  • Python (.py)"
echo "  • Ruby (.rb)"
echo
echo "Configuration: .claude/hooks/quality-config.json"
echo
echo -e "${YELLOW}Note: Hooks will be active in your next Claude session${NC}"