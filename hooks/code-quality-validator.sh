#!/bin/bash

# Simple Code Quality Validator
# Basic clean code checks

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Simple quality checks
check_file_quality() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        return 0
    fi
    
    # Basic checks only
    local line_count=$(wc -l < "$file")
    
    # Very basic limits
    if [ "$line_count" -gt 200 ]; then
        echo -e "${RED}❌ File too long: $file ($line_count lines)${NC}"
        return 1
    fi
    
    return 0
}

# Check file if provided
if [ -n "$FILE_PATH" ] && [ "$FILE_PATH" != "null" ]; then
    check_file_quality "$FILE_PATH"
fi

echo '{"continue": true}'