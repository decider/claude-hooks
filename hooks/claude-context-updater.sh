#!/bin/bash


# Source logging library
HOOK_NAME="claude-context-updater"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Log hook start
log_hook_start "$HOOK_NAME" "Hook invoked"

# Claude Context Updater Hook
# Automatically maintains CLAUDE.md files based on code changes
# Runs after file changes to create/update CLAUDE.md files

set -euo pipefail

# Configuration
ENABLE_CONTEXT_UPDATER="${ENABLE_CONTEXT_UPDATER:-true}"
AUTO_CREATE_CLAUDE_MD="${AUTO_CREATE_CLAUDE_MD:-true}"
UPDATE_EXISTING_CLAUDE_MD="${UPDATE_EXISTING_CLAUDE_MD:-true}"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
MAX_CLAUDE_MD_SIZE="${MAX_CLAUDE_MD_SIZE:-1048576}" # 1MB in bytes

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if enabled
if [ "$ENABLE_CONTEXT_UPDATER" != "true" ]; then
    exit 0
fi

# Parse hook input for file information
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only process file operations
if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
    exit 0
fi

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

echo -e "${BLUE}🤖 Claude Context Updater: Analyzing changes to $FILE_PATH...${NC}"

# Function to check file size
check_file_size() {
    local file="$1"
    local max_size="$2"
    
    if [ -f "$file" ]; then
        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        if [ "$file_size" -gt "$max_size" ]; then
            return 1  # File too large
        fi
    fi
    return 0  # File size OK or file doesn't exist
}

# Function to format bytes to human readable
format_bytes() {
    local bytes="$1"
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    else
        echo "$((bytes / 1024 / 1024))MB"
    fi
}

# Function to check if directory needs CLAUDE.md
needs_claude_md() {
    local dir="$1"
    
    # Skip certain directories (must be exact directory names, not partial paths)
    local dirname=$(basename "$dir")
    if [[ "$dirname" =~ ^(node_modules|\.git|dist|build|coverage|\.turbo)$ ]]; then
        return 1
    fi
    
    # Check if directory has enough complexity to warrant CLAUDE.md
    local file_count=$(find "$dir" -maxdepth 1 -type f -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.rs" -o -name "*.py" 2>/dev/null | wc -l)
    
    if [ "$file_count" -gt 2 ]; then
        return 0
    fi
    
    # Check for key files that indicate a module
    if [ -f "$dir/package.json" ] || [ -f "$dir/Cargo.toml" ] || [ -f "$dir/index.ts" ] || [ -f "$dir/index.js" ]; then
        return 0
    fi
    
    return 1
}

# Function to extract npm scripts from package.json
extract_npm_scripts() {
    local package_json="$1"
    if [ -f "$package_json" ]; then
        jq -r '.scripts | to_entries[] | "- `npm run \(.key)` - \(.value)"' "$package_json" 2>/dev/null || echo "- No scripts found"
    else
        echo "- No package.json found"
    fi
}

# Function to extract dependencies from package.json
extract_dependencies() {
    local package_json="$1"
    if [ -f "$package_json" ]; then
        jq -r '.dependencies // {} | to_entries[] | "- \(.key)@\(.value)"' "$package_json" 2>/dev/null | head -10 || echo "- No dependencies found"
    else
        echo "- No package.json found"
    fi
}

# Function to analyze directory structure
analyze_directory_structure() {
    local dir="$1"
    find "$dir" -maxdepth 2 -type d ! -path "$dir" ! -path "*/node_modules*" ! -path "*/.git*" ! -path "*/dist*" ! -path "*/build*" 2>/dev/null | sort | while read -r subdir; do
        local rel_path="${subdir#$dir/}"
        local file_count=$(find "$subdir" -maxdepth 1 -type f -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" 2>/dev/null | wc -l)
        if [ "$file_count" -gt 0 ]; then
            echo "├── $rel_path/ # $file_count files"
        fi
    done
}

# Function to detect key components/functions
detect_key_components() {
    local dir="$1"
    find "$dir" -maxdepth 1 -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" 2>/dev/null | while read -r file; do
        local filename=$(basename "$file")
        # Extract function/component names
        local components=$(grep -E "(export\s+(const|function|class)|^(const|function|class).*export)" "$file" 2>/dev/null | sed 's/export//g' | sed 's/const//g' | sed 's/function//g' | sed 's/class//g' | sed 's/[=({].*//' | tr -d ' ' | head -3)
        if [ -n "$components" ]; then
            echo "- \`$filename\` - $(echo "$components" | head -1)"
        fi
    done | head -8
}

# Function to generate CLAUDE.md content for a new directory
generate_claude_md_content() {
    local dir="$1"
    local dir_name=$(basename "$dir")
    local package_json="$dir/package.json"
    
    cat << EOF
# $dir_name - CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

## Overview
$(if [ -f "$package_json" ]; then jq -r '.description // "Code module for the project"' "$package_json" 2>/dev/null; else echo "Code module for the project"; fi)

## Directory Structure
\`\`\`
$(analyze_directory_structure "$dir")
\`\`\`

## Key Components
$(detect_key_components "$dir")

## Commands
$(extract_npm_scripts "$package_json")

## Dependencies
$(extract_dependencies "$package_json")

## Architecture Notes
- TypeScript/JavaScript module
- $(if [ -f "$dir/index.ts" ] || [ -f "$dir/index.js" ]; then echo "Has main index file for exports"; else echo "Individual file exports"; fi)
- $(if grep -q "import.*react" "$dir"/*.ts* 2>/dev/null; then echo "React components"; else echo "Utility functions"; fi)

---
_Auto-generated by Claude Context Updater on $(date +"%Y-%m-%d")_
EOF
}

# Function to update existing CLAUDE.md
update_existing_claude_md() {
    local claude_file="$1"
    local dir=$(dirname "$claude_file")
    local package_json="$dir/package.json"
    
    # Create backup
    cp "$claude_file" "$claude_file.backup"
    
    # Update commands section if package.json exists
    if [ -f "$package_json" ]; then
        # Extract current content before commands section
        sed '/## Commands/,$d' "$claude_file" > "$claude_file.tmp"
        
        # Add updated commands section
        echo "## Commands" >> "$claude_file.tmp"
        extract_npm_scripts "$package_json" >> "$claude_file.tmp"
        echo "" >> "$claude_file.tmp"
        
        # Add dependencies section
        echo "## Dependencies" >> "$claude_file.tmp"
        extract_dependencies "$package_json" >> "$claude_file.tmp"
        echo "" >> "$claude_file.tmp"
        
        # Add any remaining content after dependencies (if it exists)
        if grep -q "## Architecture Notes" "$claude_file"; then
            sed -n '/## Architecture Notes/,$p' "$claude_file" >> "$claude_file.tmp"
        else
            echo "## Architecture Notes" >> "$claude_file.tmp"
            echo "- Updated on $(date +"%Y-%m-%d")" >> "$claude_file.tmp"
        fi
        
        mv "$claude_file.tmp" "$claude_file"
        echo -e "${GREEN}✅ Updated CLAUDE.md: $claude_file${NC}"
    fi
}

# Main logic
if [ -n "$FILE_PATH" ]; then
    file_dir=$(dirname "$FILE_PATH")
    
    # Convert to absolute path
    if [[ "$file_dir" != /* ]]; then
        file_dir="$PROJECT_ROOT/$file_dir"
    fi
    
    # Check if directory should have CLAUDE.md
    if [ "$AUTO_CREATE_CLAUDE_MD" = "true" ] && [ ! -f "$file_dir/CLAUDE.md" ] && needs_claude_md "$file_dir"; then
        echo -e "${YELLOW}📁 Creating CLAUDE.md for directory: ${file_dir#$PROJECT_ROOT/}${NC}"
        
        content=$(generate_claude_md_content "$file_dir")
        if ! echo "$content" > "$file_dir/CLAUDE.md"; then
            echo -e "${RED}❌ Failed to create CLAUDE.md in ${file_dir#$PROJECT_ROOT/}${NC}" >&2
            log_hook_end "$HOOK_NAME" 2
            exit 2  # Block operation if CLAUDE.md creation fails
        fi
        
        echo -e "${GREEN}✅ Created: $file_dir/CLAUDE.md${NC}"
    fi
    
    # Update existing CLAUDE.md if it exists
    if [ "$UPDATE_EXISTING_CLAUDE_MD" = "true" ] && [ -f "$file_dir/CLAUDE.md" ]; then
        # Check file size before updating
        if ! check_file_size "$file_dir/CLAUDE.md" "$MAX_CLAUDE_MD_SIZE"; then
            local current_size=$(stat -f%z "$file_dir/CLAUDE.md" 2>/dev/null || stat -c%s "$file_dir/CLAUDE.md" 2>/dev/null || echo "0")
            echo -e "${RED}⚠️  WARNING: CLAUDE.md file is too large ($(format_bytes $current_size) > $(format_bytes $MAX_CLAUDE_MD_SIZE))${NC}" >&2
            echo -e "${RED}   Skipping update for: $file_dir/CLAUDE.md${NC}" >&2
            echo -e "${YELLOW}   Please check this file - it may have been corrupted or have excessive content${NC}" >&2
            log_hook_end "$HOOK_NAME" 0  # Non-blocking error
            exit 0  # Continue without blocking
        fi
        
        echo -e "${YELLOW}🔄 Updating existing CLAUDE.md in: ${file_dir#$PROJECT_ROOT/}${NC}"
        if ! update_existing_claude_md "$file_dir/CLAUDE.md"; then
            echo -e "${RED}❌ Failed to update CLAUDE.md in ${file_dir#$PROJECT_ROOT/}${NC}" >&2
            log_hook_end "$HOOK_NAME" 2
            exit 2  # Block operation if CLAUDE.md update fails
        fi
    fi
fi

echo -e "${GREEN}✅ Claude Context Updater complete!${NC}"

# Log hook completion
log_performance "$HOOK_NAME" $START_TIME
log_hook_end "$HOOK_NAME" 0

