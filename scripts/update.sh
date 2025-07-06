#!/bin/bash

# Claude Hooks Update Script
# This script updates the Claude hooks system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"

echo "🔄 Updating Claude Hooks..."

# Check if hooks are installed
if [ ! -d "$HOOKS_DIR" ]; then
    echo "❌ Claude Hooks not found. Please run install.sh first."
    exit 1
fi

# Backup current configuration
echo "💾 Backing up current configuration..."
cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.backup" 2>/dev/null || true

# Update hooks
echo "📁 Updating hook scripts..."
cp -r "$REPO_DIR/hooks/"* "$HOOKS_DIR/"

# Make hooks executable
echo "🔐 Making hooks executable..."
chmod +x "$HOOKS_DIR"/*.sh

# Update configuration with new options (preserve user settings)
echo "⚙️ Updating configuration..."
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    # Create a merged configuration
    python3 -c "
import json
import sys

try:
    with open('$CLAUDE_DIR/settings.json', 'r') as f:
        current = json.load(f)
    with open('$REPO_DIR/config/settings.example.json', 'r') as f:
        template = json.load(f)
    
    # Merge configurations (template provides new keys, current preserves user values)
    def merge_dict(template, current):
        for key, value in template.items():
            if key not in current:
                current[key] = value
            elif isinstance(value, dict) and isinstance(current[key], dict):
                merge_dict(value, current[key])
        return current
    
    merged = merge_dict(template, current)
    
    with open('$CLAUDE_DIR/settings.json', 'w') as f:
        json.dump(merged, f, indent=2)
    
    print('Configuration updated successfully')
except Exception as e:
    print(f'Warning: Could not update configuration: {e}')
    print('Please review your settings.json file manually')
" 2>/dev/null || echo "Note: Configuration merge failed, using existing settings"
fi

# Rebuild code index
echo "📊 Rebuilding code index..."
"$HOOKS_DIR/build-code-index.sh" 2>/dev/null || echo "Note: Code index build failed"

# Show current version
VERSION=$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo "unknown")
echo "✅ Claude Hooks updated to version $VERSION"
echo ""
echo "🎉 Update complete! The new hooks are now active."