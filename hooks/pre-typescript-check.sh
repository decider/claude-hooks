#!/bin/bash

# Pre-TypeScript Check Hook
# Validates TypeScript compilation before allowing operations that might trigger pre-commit hooks
# This prevents wasted time on commits that will fail due to TS errors

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Initialize
HOOK_NAME="pre-typescript-check"
INPUT="$1"

log_hook_start "$HOOK_NAME" "$INPUT"

# Check if this is a git commit command
COMMAND=$(echo "$INPUT" | jq -r '.command // ""' 2>/dev/null)
if [[ ! "$COMMAND" =~ ^git[[:space:]]+commit ]]; then
    log_info "$HOOK_NAME" "Not a git commit command, skipping"
    log_hook_end "$HOOK_NAME" 0
    exit 0
fi

# Check if we're in a TypeScript project
if [ ! -f "tsconfig.json" ] && [ ! -f "package.json" ]; then
    log_info "$HOOK_NAME" "No TypeScript configuration found, skipping"
    log_hook_end "$HOOK_NAME" 0
    exit 0
fi

# Determine which TypeScript command to use
TSC_COMMAND=""
if [ -f "package.json" ] && grep -q '"typecheck"' package.json 2>/dev/null; then
    TSC_COMMAND="npm run typecheck"
    log_info "$HOOK_NAME" "Using npm run typecheck"
elif [ -f "package.json" ] && grep -q '"type-check"' package.json 2>/dev/null; then
    TSC_COMMAND="npm run type-check"
    log_info "$HOOK_NAME" "Using npm run type-check"
elif [ -f "package.json" ] && grep -q '"tsc"' package.json 2>/dev/null; then
    TSC_COMMAND="npm run tsc"
    log_info "$HOOK_NAME" "Using npm run tsc"
elif command -v tsc &> /dev/null; then
    TSC_COMMAND="tsc --noEmit"
    log_info "$HOOK_NAME" "Using tsc --noEmit"
else
    log_warn "$HOOK_NAME" "No TypeScript compiler found, skipping"
    log_hook_end "$HOOK_NAME" 0
    exit 0
fi

# Run TypeScript check
log_info "$HOOK_NAME" "Running TypeScript validation: $TSC_COMMAND"
TSC_OUTPUT=$($TSC_COMMAND 2>&1)
TSC_EXIT_CODE=$?

if [ $TSC_EXIT_CODE -ne 0 ]; then
    # Count errors
    ERROR_COUNT=$(echo "$TSC_OUTPUT" | grep -c "error TS")
    
    # Create a summary of unique error types
    UNIQUE_ERRORS=$(echo "$TSC_OUTPUT" | grep "error TS" | sed 's/.*error \(TS[0-9]*\):.*/\1/' | sort | uniq -c | sort -rn | head -5)
    
    # Get first few errors as examples
    FIRST_ERRORS=$(echo "$TSC_OUTPUT" | grep "error TS" | head -3)
    
    # Output detailed error information to stderr
    echo "❌ TypeScript compilation failed with $ERROR_COUNT errors:" >&2
    echo "$TSC_OUTPUT" >&2
    echo "" >&2
    echo "Top error types:" >&2
    echo "$UNIQUE_ERRORS" >&2
    echo "" >&2
    echo "Run '$TSC_COMMAND' to see all errors." >&2
    
    # Log the failure
    log_error_context "$HOOK_NAME" "TypeScript compilation failed" "$TSC_COMMAND" "$TSC_OUTPUT"
    log_error "$HOOK_NAME" "TypeScript compilation failed with $ERROR_COUNT errors"
    log_decision "$HOOK_NAME" "block" "TypeScript errors must be fixed before committing"
    
    # Prepare the response
    RESPONSE=$(cat <<EOF
{
  "action": "block",
  "reason": "TypeScript compilation failed with $ERROR_COUNT errors. Please fix these before committing:",
  "details": {
    "errorCount": $ERROR_COUNT,
    "topErrors": $(echo "$UNIQUE_ERRORS" | jq -R -s 'split("\n") | map(select(length > 0))'),
    "examples": $(echo "$FIRST_ERRORS" | jq -R -s 'split("\n") | map(select(length > 0))'),
    "suggestion": "Run '$TSC_COMMAND' to see all errors, then fix them before committing."
  }
}
EOF
)
    
    echo "$RESPONSE"
    log_hook_end "$HOOK_NAME" 1
    exit 1
else
    log_info "$HOOK_NAME" "TypeScript compilation successful"
    log_decision "$HOOK_NAME" "allow" "No TypeScript errors found"
    log_hook_end "$HOOK_NAME" 0
    exit 0
fi