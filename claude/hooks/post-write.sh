#!/bin/bash


# Source logging library
HOOK_NAME="post-write"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Log hook start
log_hook_start "$HOOK_NAME" "Hook invoked"

# Post-write hook for Claude Code
# Runs after any file write operation to catch issues early

FILE_PATH="$1"
PROJECT_ROOT="$(pwd)"
HOOK_DIR="$(dirname "$0")"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Only run for code files
if [[ "$FILE_PATH" =~ \.(ts|tsx|js|jsx|py|go|rs)$ ]]; then
    echo -e "${YELLOW}🔍 Running post-write checks for $FILE_PATH...${NC}"
    
    # Quick TypeScript check for TS files
    if [[ "$FILE_PATH" =~ \.(ts|tsx)$ ]] && command -v npx &> /dev/null; then
        echo -e "${YELLOW}Checking TypeScript...${NC}"
        
        # Check just this file for errors
        TS_OUTPUT=$(npx tsc --noEmit "$FILE_PATH" 2>&1 || true)
        
        if echo "$TS_OUTPUT" | grep -q "error TS"; then
            echo -e "${RED}❌ TypeScript errors detected:${NC}"
            echo "$TS_OUTPUT" | grep "error TS" | head -5
            echo -e "${YELLOW}Fix these errors before continuing!${NC}"
        else
            echo -e "${GREEN}✓ No TypeScript errors${NC}"
        fi
    fi
    
    # Check for missing imports
    if grep -q "Cannot find module\|Module not found" "$FILE_PATH" 2>/dev/null; then
        echo -e "${RED}⚠️  Warning: File contains unresolved imports${NC}"
    fi
fi

# Run existing code quality validator if it exists
if [ -f "$HOOK_DIR/code-quality-validator.sh" ]; then
    "$HOOK_DIR/code-quality-validator.sh" "$FILE_PATH"
fi

# Log hook completion
log_performance "$HOOK_NAME" $START_TIME
log_hook_end "$HOOK_NAME" 0
