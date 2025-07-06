#!/bin/bash

# Claude Code Hooks Setup Script
# This script sets up all the team hooks for a developer

set -euo pipefail

echo "🚀 Claude Code Hooks Setup"
echo "=========================="

# Check if running from project root
if [ ! -f "claude/hooks/check-package-age.sh" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

PROJECT_ROOT=$(pwd)
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"

# Create directories
echo "📁 Creating directories..."
mkdir -p "$CLAUDE_DIR"
mkdir -p "$HOOKS_DIR"

# Copy all hooks
echo "📋 Copying hooks..."
cp "$PROJECT_ROOT/claude/hooks/"*.sh "$HOOKS_DIR/"
cp "$PROJECT_ROOT/claude/hooks/"*.json "$HOOKS_DIR/"

# Make hooks executable
echo "🔧 Making hooks executable..."
chmod +x "$HOOKS_DIR/"*.sh

# Check if settings.json exists
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    echo "⚠️  Found existing settings.json"
    echo "   Please manually merge the settings from claude/settings.example.json"
    echo "   Or backup your current settings and run:"
    echo "   cp claude/settings.example.json ~/.claude/settings.json"
else
    echo "📝 Creating settings.json..."
    cp "$PROJECT_ROOT/claude/settings.example.json" "$CLAUDE_DIR/settings.json"
    
    # Update paths in settings.json to use absolute paths
    sed -i.bak "s|~/.claude/hooks/|$HOOKS_DIR/|g" "$CLAUDE_DIR/settings.json"
    rm "$CLAUDE_DIR/settings.json.bak"
fi

# Build initial code index
echo "🔍 Building code index (this may take a moment)..."
"$HOOKS_DIR/quick-index.sh" || echo "   Note: Index building can be run manually later"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📚 Installed hooks:"
echo "   1. Package Age Validator - Prevents outdated npm packages"
echo "   2. Code Quality Primer - Reminds about Clean Code principles"
echo "   3. Code Quality Validator - Validates code against rules"
echo "   4. Code Similarity Checker - Detects duplicate code"
echo "   5. Task Completion Notifier - System notifications"
echo "   6. Pre-Completion Quality Check - Runs lints/tests before completion"
echo "   7. Claude Context Updater - Maintains CLAUDE.md files automatically"
echo ""
echo "📖 Documentation:"
echo "   - Hooks guide: $HOOKS_DIR/README.md"
echo "   - Clean Code guide: $HOOKS_DIR/CLEAN-CODE-GUIDE.md"
echo ""
echo "🔧 Configuration:"
echo "   - Settings: $CLAUDE_DIR/settings.json"
echo "   - Rules: $HOOKS_DIR/clean-code-rules.json"
echo ""
echo "💡 Tips:"
echo "   - Rebuild index anytime: ~/.claude/hooks/build-code-index.sh"
echo "   - Quick index: ~/.claude/hooks/quick-index.sh"
echo "   - Customize rules in clean-code-rules.json"
echo ""
echo "🎉 Happy coding with Clean Code principles!"