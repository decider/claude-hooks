#!/bin/bash

# Single purpose TypeScript checker
# Just checks TypeScript - nothing else

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/validation.sh"

# Simple and direct
if run_typescript_check "${PROJECT_DIR:-.}" "$HOOK_INCLUDE" "$HOOK_EXCLUDE"; then
    echo "✅ TypeScript check passed"
    exit 0
else
    echo "❌ TypeScript errors found" >&2
    [ -n "$TS_OUTPUT" ] && echo "$TS_OUTPUT" >&2
    
    # Extract error count from TypeScript output
    ERROR_COUNT=$(echo "$TS_OUTPUT" | grep -cE "error TS[0-9]+:" || echo "0")
    if [ "$ERROR_COUNT" -eq 0 ]; then
        # Fallback - count generic error lines
        ERROR_COUNT=$(echo "$TS_OUTPUT" | grep -cE "(error|Error)" || echo "some")
    fi
    
    # Extract specific TypeScript errors
    TS_ERRORS=$(echo "$TS_OUTPUT" | grep -E "error TS[0-9]+:" | head -5 | sed 's/^/• /')
    
    # Get unique error codes with counts
    ERROR_TYPES=$(echo "$TS_OUTPUT" | grep -oE "TS[0-9]+" | sort | uniq -c | sort -rn | head -3 | sed 's/^[[:space:]]*/• /')
    
    # Build reason message for Claude
    REASON="Found $ERROR_COUNT TypeScript errors. Please fix these type errors:\n\n$TS_ERRORS"
    
    if [ -n "$ERROR_TYPES" ]; then
        REASON="$REASON\n\nMost common error types:\n$ERROR_TYPES"
    fi
    
    REASON="$REASON\n\nRun 'npm run typecheck' to see all errors."
    
    # Output JSON for Claude Code
    cat <<EOF
{
  "continue": false,
  "stopReason": "TypeScript compilation errors - cannot proceed",
  "decision": "block",
  "reason": "$REASON"
}
EOF
    exit 0  # Use exit 0 when outputting JSON
fi