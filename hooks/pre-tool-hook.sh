#!/bin/bash

# Direct PreToolUse Hook Handler - No Node.js dependencies
# Analyzes code BEFORE Write/Edit/MultiEdit operations

set -euo pipefail

# Read input from stdin
INPUT=$(cat)

# Extract relevant fields using grep and sed (portable)
EVENT_TYPE=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4)
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)

# Only process PreToolUse events
if [[ "$EVENT_TYPE" != "PreToolUse" ]]; then
    exit 0
fi

# Only process Write/Edit/MultiEdit tools
if [[ ! "$TOOL_NAME" =~ ^(Write|Edit|MultiEdit)$ ]]; then
    exit 0
fi

# Extract file path and content
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

# Extract content (handle both Write's content and Edit's new_string)
CONTENT=$(echo "$INPUT" | grep -o '"content":"[^"]*"' | cut -d'"' -f4 || true)
if [[ -z "$CONTENT" ]]; then
    CONTENT=$(echo "$INPUT" | grep -o '"new_string":"[^"]*"' | cut -d'"' -f4 || true)
fi

# Skip if no content or file path
if [[ -z "$CONTENT" ]] || [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

# Skip non-code files
case "$EXT" in
    md|txt|json|yml|yaml|xml|html|css)
        exit 0
        ;;
esac

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the quality checks
source "$SCRIPT_DIR/common/code-quality/loader.sh"

# Check content quality based on file type
case "$EXT" in
    ts|tsx|js|jsx)
        # TypeScript/JavaScript checks
        # Note: This is simplified - full analysis would need proper parsing
        
        # Check for obvious violations
        if echo "$CONTENT" | grep -qE '^\s{8}'; then
            cat <<EOF
{
  "decision": "block",
  "reason": "Deep nesting detected. Please refactor to reduce nesting levels."
}
EOF
            exit 0
        fi
        
        # Check for long lines
        if echo "$CONTENT" | grep -qE '^.{101,}'; then
            cat <<EOF
{
  "decision": "block",
  "reason": "Lines exceed 100 characters. Please break long lines."
}
EOF
            exit 0
        fi
        ;;
        
    py)
        # Python checks
        # Check for PEP8 violations
        if echo "$CONTENT" | grep -qE '^\s{5,}[^#]'; then
            cat <<EOF
{
  "decision": "block",
  "reason": "Python indentation should be 4 spaces (PEP8). Found inconsistent indentation."
}
EOF
            exit 0
        fi
        ;;
        
    rb)
        # Ruby checks
        # Check for Ruby style guide violations
        if echo "$CONTENT" | grep -qE '^\s{3,}[^#]'; then
            cat <<EOF
{
  "decision": "block",
  "reason": "Ruby indentation should be 2 spaces. Found inconsistent indentation."
}
EOF
            exit 0
        fi
        ;;
esac

# If all checks pass, allow the operation
exit 0