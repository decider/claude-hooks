#!/bin/bash

# Claude Hooks Installation Script
# This script installs Claude hooks system to ~/.claude/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"

echo "🔧 Installing Claude Hooks..."

# Create directories
mkdir -p "$HOOKS_DIR"
mkdir -p "$CLAUDE_DIR"

# Copy hooks
echo "📁 Copying hook scripts..."
cp -r "$REPO_DIR/hooks/"* "$HOOKS_DIR/"

# Make hooks executable
echo "🔐 Making hooks executable..."
chmod +x "$HOOKS_DIR"/*.sh

# Copy configuration if it doesn't exist
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    echo "⚙️ Creating default configuration..."
    cp "$REPO_DIR/config/settings.example.json" "$CLAUDE_DIR/settings.json"
else
    echo "⚙️ Configuration already exists, skipping..."
fi

# Build code index
echo "📊 Building code index..."
"$HOOKS_DIR/build-code-index.sh" 2>/dev/null || echo "Note: Code index build failed (this is normal for first install)"

# Verify installation
echo "✅ Verifying installation..."
if [ -d "$HOOKS_DIR" ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
    echo "✨ Claude Hooks installed successfully!"
    echo ""
    echo "📍 Installation location: $CLAUDE_DIR"
    echo "🎯 Configuration file: $CLAUDE_DIR/settings.json"
    echo ""
    echo "🎉 Ready to use! The hooks will automatically activate when you use Claude Code."
else
    echo "❌ Installation failed. Please check the error messages above."
    exit 1
fi