#!/bin/bash

# Claude Hooks Project Installation Script
# This script installs Claude hooks as a git submodule in the current project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="${1:-https://github.com/your-org/claude-hooks.git}"
PROJECT_ROOT="$(pwd)"

echo "🔧 Installing Claude Hooks as project submodule..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ This script must be run in a git repository"
    exit 1
fi

# Add submodule
echo "📦 Adding claude-hooks as git submodule..."
git submodule add "$REPO_URL" claude-hooks

# Create project-level claude directory
echo "📁 Creating project-level claude directory..."
mkdir -p claude

# Copy hooks to project
echo "📋 Copying hooks to project..."
cp -r claude-hooks/hooks claude/
cp claude-hooks/config/settings.example.json claude/settings.json

# Make hooks executable
echo "🔐 Making hooks executable..."
chmod +x claude/hooks/*.sh

# Create project-specific setup script
echo "📝 Creating project setup script..."
cat > claude/setup-hooks.sh << 'EOF'
#!/bin/bash

# Project-specific Claude Hooks Setup
# This script sets up hooks for this specific project

set -e

CLAUDE_DIR="$HOME/claude"
PROJECT_DIR="$(pwd)"

echo "🔧 Setting up project-specific Claude Hooks..."

# Create user claude directory
mkdir -p "$CLAUDE_DIR/hooks"

# Copy project hooks to user directory
echo "📁 Copying project hooks..."
cp -r "$PROJECT_DIR/claude/hooks/"* "$CLAUDE_DIR/hooks/"

# Make hooks executable
echo "🔐 Making hooks executable..."
chmod +x "$CLAUDE_DIR/hooks/"*.sh

# Copy project settings if user doesn't have settings
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    echo "⚙️ Creating user configuration from project template..."
    cp "$PROJECT_DIR/claude/settings.json" "$CLAUDE_DIR/settings.json"
else
    echo "⚙️ User configuration already exists, skipping..."
fi

# Build code index
echo "📊 Building code index..."
"$CLAUDE_DIR/hooks/build-code-index.sh" 2>/dev/null || echo "Note: Code index build failed"

echo "✅ Project hooks setup complete!"
echo ""
echo "🎯 To update hooks, run: git submodule update --remote claude-hooks"
echo "🎯 Then run this script again to copy the updates"
EOF

chmod +x claude/setup-hooks.sh

# Initialize submodule
echo "🔄 Initializing submodule..."
git submodule update --init --recursive

echo "✅ Claude Hooks installed as project submodule!"
echo ""
echo "📍 Location: ./claude-hooks/ (submodule)"
echo "📍 Project hooks: ./claude/"
echo ""
echo "🎯 Next steps:"
echo "  1. Run: ./claude/setup-hooks.sh"
echo "  2. Commit the changes: git add . && git commit -m 'Add claude-hooks submodule'"
echo "  3. Team members should run: git submodule update --init --recursive"
echo "  4. Then: ./claude/setup-hooks.sh"