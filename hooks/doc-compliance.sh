#!/bin/bash

# Simple Documentation Compliance Hook
# Basic checks for documentation standards

HOOK_INPUT=$(cat)
EVENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Simple file checks
check_documentation() {
    local file="$1"
    
    # Basic checks only
    if [[ "$file" =~ \.(md|txt)$ ]]; then
        if [ ! -s "$file" ]; then
            echo -e "${RED}❌ Empty documentation file: $file${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Process files if provided
if echo "$HOOK_INPUT" | jq -e '.tool_input.file_path' >/dev/null 2>&1; then
    FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path')
    if [ -f "$FILE_PATH" ]; then
        check_documentation "$FILE_PATH"
    fi
fi

echo '{"continue": true}'