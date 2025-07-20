#!/bin/bash

# Code Quality Validator Hook
# Enforces clean code standards using modular checks

# Source the quality checks loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/code-quality/loader.sh"

# Read input
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // 0')

# FUCKING LOG EVERYTHING
LOG_FILE="/Users/danseider/claude-hooks/.claude/hooks/code-quality.log"
echo "[$(date)] CODE QUALITY VALIDATOR STARTED" >> "$LOG_FILE"
echo "[$(date)] Input: ${INPUT:0:200}..." >> "$LOG_FILE"
echo "[$(date)] TOOL: $TOOL, FILE_PATH: $FILE_PATH, EXIT_CODE: $EXIT_CODE" >> "$LOG_FILE"

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

echo "[$(date)] Event type: $EVENT_TYPE" >> "$LOG_FILE"

if [[ "$EVENT_TYPE" == "Stop" ]]; then
    echo "[$(date)] Processing Stop event" >> "$LOG_FILE"
    # For Stop events, check recently modified files
    
    # Find all TypeScript files modified in the last 10 minutes (exclude node_modules and .d.ts)
    RECENT_FILES=$(find . \( -name "*.ts" -o -name "*.tsx" \) -mtime -10m 2>/dev/null | grep -v node_modules | grep -v "\.d\.ts$" | head -20)
    
    echo "[$(date)] Found files: $RECENT_FILES" >> "$LOG_FILE"
    
    TOTAL_VIOLATIONS=0
    VIOLATIONS_DETAIL=""
    for file in $RECENT_FILES; do
        if [[ -f "$file" ]] && [[ ! "$file" =~ (test|spec|\.d\.ts)\. ]]; then
            echo "[$(date)] Checking: $file" >> "$LOG_FILE"
            # Redirect check output to capture it
            CHECK_OUTPUT=$(run_all_quality_checks "$file" "$RULES_FILE" 2>&1)
            VIOLATIONS_FOUND=$?
            TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + VIOLATIONS_FOUND))
            if [[ $VIOLATIONS_FOUND -gt 0 ]]; then
                VIOLATIONS_DETAIL="${VIOLATIONS_DETAIL}\n${file}: ${VIOLATIONS_FOUND} violations"
            fi
        fi
    done
    
    if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
        echo "[$(date)] All checks passed" >> "$LOG_FILE"
        echo '{"continue": true}'
    else
        echo "[$(date)] Found $TOTAL_VIOLATIONS violations" >> "$LOG_FILE"
        
        # Block if violations exceed threshold
        BLOCK_THRESHOLD="${CODE_QUALITY_BLOCK_THRESHOLD:-0}"  # Default: ALWAYS BLOCK
        
        if [[ $TOTAL_VIOLATIONS -gt $BLOCK_THRESHOLD ]]; then
            echo "[$(date)] BLOCKING! Violations: $TOTAL_VIOLATIONS, Threshold: $BLOCK_THRESHOLD" >> "$LOG_FILE"
            cat <<EOF
{
  "continue": false,
  "stopReason": "Code quality violations in recent files",
  "decision": "block",
  "reason": "Found $TOTAL_VIOLATIONS total code quality violations across recent files (threshold: $BLOCK_THRESHOLD).\n\nClean code principles violated:\n- Functions too long\n- Deep nesting\n- Magic numbers\n- High comment ratio\n\nPlease refactor before proceeding."
}
EOF
        else
            echo "[$(date)] NOT BLOCKING - Violations: $TOTAL_VIOLATIONS, Threshold: $BLOCK_THRESHOLD" >> "$LOG_FILE"
            echo '{"continue": true}'
        fi
    fi
    echo "[$(date)] Exiting Stop event handler" >> "$LOG_FILE"
    exit 0
fi

# For tool events, check specific file
if [[ ! "$TOOL" =~ ^(Write|Edit|MultiEdit)$ ]] || [[ "$EXIT_CODE" != "0" ]] || [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" == "null" ]]; then
    echo "[$(date)] Skipping - TOOL: $TOOL, EXIT_CODE: $EXIT_CODE, FILE_PATH: $FILE_PATH" >> "$LOG_FILE"
    echo '{"continue": true}'
    exit 0
fi

# Skip non-TypeScript files
if [[ ! "$FILE_PATH" =~ \.(ts|tsx)$ ]]; then
    echo "[$(date)] Skipping non-TS file: $FILE_PATH" >> "$LOG_FILE"
    echo '{"continue": true}'
    exit 0
fi

# Skip test files
if [[ "$FILE_PATH" =~ (test|spec)\. ]]; then
    echo "[$(date)] Skipping test file: $FILE_PATH" >> "$LOG_FILE"
    echo '{"continue": true}'
    exit 0
fi

echo "[$(date)] Checking file: $FILE_PATH" >> "$LOG_FILE"

# Run all quality checks
CHECK_OUTPUT=$(run_all_quality_checks "$FILE_PATH" "$RULES_FILE" 2>&1)
VIOLATIONS=$?

if [[ $VIOLATIONS -eq 0 ]]; then
    echo "[$(date)] All checks passed for $FILE_PATH" >> "$LOG_FILE"
    echo '{"continue": true}'
    exit 0
else
    echo "[$(date)] Found $VIOLATIONS violations in $FILE_PATH" >> "$LOG_FILE"
    
    # Block if violations exceed threshold (configurable)
    BLOCK_THRESHOLD="${CODE_QUALITY_BLOCK_THRESHOLD:-0}"  # Default: ALWAYS BLOCK
    
    if [[ $VIOLATIONS -gt $BLOCK_THRESHOLD ]]; then
        echo "[$(date)] BLOCKING file edit! Violations: $VIOLATIONS, Threshold: $BLOCK_THRESHOLD" >> "$LOG_FILE"
        cat <<EOF
{
  "continue": false,
  "stopReason": "Code quality violations exceed threshold",
  "decision": "block",
  "reason": "Found $VIOLATIONS code quality violations (threshold: $BLOCK_THRESHOLD).\n\nPlease fix:\n- Functions exceeding max length\n- Deep nesting levels\n- Magic numbers\n- Other clean code violations\n\nRun code quality checks locally to see all issues."
}
EOF
    else
        echo "[$(date)] NOT BLOCKING file edit - Violations: $VIOLATIONS, Threshold: $BLOCK_THRESHOLD" >> "$LOG_FILE"
        echo '{"continue": true}'
    fi
    exit 0
fi