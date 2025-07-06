#!/bin/bash

# Update Vendored Claude Hooks
# This script updates vendored claude-hooks in a project
# It should be copied to your project's scripts directory

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
CLAUDE_HOOKS_SOURCE="${CLAUDE_HOOKS_SOURCE:-$HOME/claude-hooks}"
CLAUDE_HOOKS_DEST="./claude-hooks"

echo -e "${YELLOW}🔄 Updating Vendored Claude Hooks...${NC}"

# Safety check: Don't run from within the claude-hooks repo itself
if [ -f "./scripts/update-vendored.sh" ] && [ -f "./hooks/check-package-age.sh" ]; then
    echo -e "${RED}❌ Error: Cannot run this script from within the claude-hooks repository${NC}"
    echo "This script is meant to update vendored claude-hooks in other projects."
    echo ""
    echo "To update your local installation, use: ./scripts/update.sh"
    exit 1
fi

# Check if we're in a project with vendored hooks
if [ ! -d "$CLAUDE_HOOKS_DEST" ]; then
    echo -e "${RED}❌ No vendored claude-hooks found in this project${NC}"
    echo "Expected to find: $CLAUDE_HOOKS_DEST"
    exit 1
fi

# Check if source exists
if [ ! -d "$CLAUDE_HOOKS_SOURCE" ]; then
    echo -e "${RED}❌ Claude Hooks source not found at $CLAUDE_HOOKS_SOURCE${NC}"
    echo "Options:"
    echo "  1. Clone it: git clone https://github.com/decider/claude-hooks.git ~/claude-hooks"
    echo "  2. Set custom path: CLAUDE_HOOKS_SOURCE=/path/to/claude-hooks $0"
    exit 1
fi

# Get current version
CURRENT_VERSION=""
if [ -f "$CLAUDE_HOOKS_DEST/VERSION" ]; then
    CURRENT_VERSION=$(cat "$CLAUDE_HOOKS_DEST/VERSION")
fi

# Update the source repository
echo -e "${YELLOW}📥 Updating source repository...${NC}"
(cd "$CLAUDE_HOOKS_SOURCE" && git pull --quiet) || echo "Note: Could not pull latest changes"

# Get new version
NEW_VERSION=""
if [ -f "$CLAUDE_HOOKS_SOURCE/VERSION" ]; then
    NEW_VERSION=$(cat "$CLAUDE_HOOKS_SOURCE/VERSION")
fi

# Show what will be updated
if [ -n "$CURRENT_VERSION" ] && [ -n "$NEW_VERSION" ]; then
    if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
        echo -e "${YELLOW}📋 Version change: $CURRENT_VERSION → $NEW_VERSION${NC}"
    else
        echo -e "${GREEN}✅ Already at version $CURRENT_VERSION${NC}"
    fi
fi

# Create backup
if [ -d "$CLAUDE_HOOKS_DEST" ]; then
    echo -e "${YELLOW}💾 Creating backup...${NC}"
    rm -rf "$CLAUDE_HOOKS_DEST.backup"
    cp -r "$CLAUDE_HOOKS_DEST" "$CLAUDE_HOOKS_DEST.backup"
fi

# Copy files
echo -e "${YELLOW}📁 Copying updated hooks...${NC}"
mkdir -p "$CLAUDE_HOOKS_DEST"

# Copy everything except .git and certain files
rsync -av \
    --exclude='.git' \
    --exclude='.gitignore' \
    --exclude='CLAUDE.local.md' \
    --exclude='claude' \
    "$CLAUDE_HOOKS_SOURCE/" "$CLAUDE_HOOKS_DEST/"

# Make hooks executable
chmod +x "$CLAUDE_HOOKS_DEST/hooks/"*.sh 2>/dev/null || true
chmod +x "$CLAUDE_HOOKS_DEST/scripts/"*.sh 2>/dev/null || true
chmod +x "$CLAUDE_HOOKS_DEST/tools/"*.sh 2>/dev/null || true

# Show changes
echo -e "${GREEN}✅ Claude Hooks updated successfully!${NC}"

# Check for changes
if command -v git >/dev/null 2>&1; then
    CHANGES=$(git status --porcelain "$CLAUDE_HOOKS_DEST" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CHANGES" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}📝 Changes detected:${NC}"
        git status --short "$CLAUDE_HOOKS_DEST" 2>/dev/null || true
        echo ""
        echo -e "${YELLOW}💡 To commit these changes:${NC}"
        echo "  git add $CLAUDE_HOOKS_DEST/"
        echo "  git commit -m \"chore: update claude-hooks to version $NEW_VERSION\""
    else
        echo -e "${GREEN}✅ No changes detected${NC}"
    fi
fi

# Cleanup backup if successful
if [ -d "$CLAUDE_HOOKS_DEST.backup" ]; then
    rm -rf "$CLAUDE_HOOKS_DEST.backup"
fi

echo ""
echo -e "${GREEN}🎉 Update complete!${NC}"
echo ""
echo -e "${YELLOW}📚 Next steps:${NC}"
echo "  1. Review the changes with: git diff $CLAUDE_HOOKS_DEST/"
echo "  2. Run setup if needed: ./claude/setup-hooks.sh"
echo "  3. Check logs at: $HOME/claude/logs/hooks.log"