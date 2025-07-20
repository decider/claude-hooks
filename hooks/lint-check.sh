#!/bin/bash

# Single purpose lint checker
# Just runs linting - nothing else

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/validation.sh"

PROJECT_DIR="${PROJECT_DIR:-.}"

# Check if lint is available
if ! has_lint_script "$PROJECT_DIR"; then
    echo "No lint script found in package.json"
    exit 0
fi

# Build file list (supports staged files if CHECK_STAGED is set)
FILES_TO_LINT=$(build_lint_file_list "$PROJECT_DIR" "$HOOK_FILES" "$HOOK_INCLUDE" "$HOOK_EXCLUDE" "${CHECK_STAGED:-false}")

# Run lint
if run_lint_check "$PROJECT_DIR" "$FILES_TO_LINT"; then
    echo "✅ Lint check passed"
    exit 0
else
    echo "❌ Lint errors found" >&2
    [ -n "$LINT_OUTPUT" ] && echo "$LINT_OUTPUT" >&2
    
    # Extract error count and details for JSON output
    ERROR_COUNT=$(echo "$LINT_OUTPUT" | grep -cE "(error|Error|ERROR)" || echo "0")
    
    # Build fix command based on available scripts
    FIX_CMD="npm run lint"
    if [ -f "$PROJECT_DIR/package.json" ] && grep -q '"lint:fix"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        FIX_CMD="npm run lint:fix"
    fi
    
    # Extract first few errors as examples
    ERROR_EXAMPLES=$(echo "$LINT_OUTPUT" | grep -E "(error|Error|ERROR)" | head -5 | sed 's/^/• /')
    
    # Build reason message for Claude
    REASON="Linting errors found. Please fix these issues:\n\n$ERROR_EXAMPLES\n\nTo fix automatically fixable issues, run: $FIX_CMD"
    
    # Output JSON for Claude Code
    cat <<EOF
{
  "continue": false,
  "stopReason": "Code has linting errors - cannot proceed",
  "decision": "block", 
  "reason": "$REASON"
}
EOF
    exit 0  # Use exit 0 when outputting JSON
fi