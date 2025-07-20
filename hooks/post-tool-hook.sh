#!/bin/bash

# Direct PostToolUse Hook Handler - No Node.js dependencies
# Processes PostToolUse events for Write/Edit/MultiEdit operations

set -euo pipefail

# Read input from stdin
INPUT=$(cat)

# Extract relevant fields using grep and sed (portable)
EVENT_TYPE=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4)
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)

# Only process PostToolUse events
if [[ "$EVENT_TYPE" != "PostToolUse" ]]; then
    exit 0
fi

# Only process Write/Edit/MultiEdit tools
if [[ ! "$TOOL_NAME" =~ ^(Write|Edit|MultiEdit)$ ]]; then
    exit 0
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" == "null" ]]; then
    exit 0
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Forward to the quality validator
echo "$INPUT" | "$SCRIPT_DIR/code-quality-validator.sh"