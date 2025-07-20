#!/bin/bash

# Code Quality Validator Hook
# Enforces clean code standards using modular checks

# Source the quality checks loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/code-quality/loader.sh"

# Read input
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // 0')

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
RULES_FILE="${CLAUDE_RULES_FILE:-$SCRIPT_DIR/clean-code-rules.json}"

# Check if this is a Stop event (no tool)
EVENT_TYPE=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)

if [[ "$EVENT_TYPE" == "Stop" ]]; then
    # For Stop events, check recently modified files
    echo -e "${CYAN}🔍 Running code quality checks on recently modified files...${NC}"
    
    # Find files modified in the last 5 minutes
    RECENT_FILES=$(find . -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.rs" -o -name "*.go" -o -name "*.java" | \
                   xargs -I {} sh -c 'test -f "{}" && echo "{}"' | \
                   xargs ls -lt 2>/dev/null | head -10 | awk '{print $NF}')
    
    TOTAL_VIOLATIONS=0
    for file in $RECENT_FILES; do
        if [[ -f "$file" ]] && [[ ! "$file" =~ (test|spec)\. ]]; then
            echo -e "\nChecking: $file"
            if ! run_all_quality_checks "$file" "$RULES_FILE"; then
                TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + $?))
            fi
        fi
    done
    
    if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
        echo -e "\n${GREEN}✅ All code quality checks passed${NC}"
    else
        echo -e "\n${RED}❌ Found $TOTAL_VIOLATIONS total code quality violation(s)${NC}"
        echo -e "${YELLOW}💡 Consider refactoring to improve code quality${NC}"
    fi
    
    echo '{"continue": true}'
    exit 0
fi

# For tool events, check specific file
if [[ ! "$TOOL" =~ ^(Write|Edit|MultiEdit)$ ]] || [[ "$EXIT_CODE" != "0" ]] || [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" == "null" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Skip non-code files
if [[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|py|rs|go|java)$ ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Skip test files
if [[ "$FILE_PATH" =~ (test|spec)\. ]]; then
    echo '{"continue": true}'
    exit 0
fi

echo -e "${CYAN}🔍 Running code quality checks on ${FILE_PATH}...${NC}"

# Run all quality checks
if run_all_quality_checks "$FILE_PATH" "$RULES_FILE"; then
    echo -e "${GREEN}✅ All code quality checks passed${NC}"
    echo '{"continue": true}'
    exit 0
else
    VIOLATIONS=$?
    echo -e "\n${RED}❌ Found $VIOLATIONS code quality violation(s)${NC}"
    echo -e "${YELLOW}💡 Consider refactoring to improve code quality${NC}"
    
    # Still allow continuation but warn
    echo '{"continue": true}'
    exit 0
fi