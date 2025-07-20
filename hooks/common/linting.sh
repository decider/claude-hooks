#!/bin/bash

# Linting validation functions
# Simple and focused on linting checks only

# Check if lint script exists
has_lint_script() {
    local dir="${1:-.}"
    
    if [ -f "$dir/package.json" ] && grep -q '"lint"' "$dir/package.json" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Run lint check
run_lint_check() {
    local dir="${1:-.}"
    
    LINT_OUTPUT=""
    
    if ! has_lint_script "$dir"; then
        return 0  # No lint script
    fi
    
    LINT_OUTPUT=$(cd "$dir" && npm run lint 2>&1 || true)
    
    # Check for errors
    if echo "$LINT_OUTPUT" | grep -qE "(error|Error|ERROR|failed|Failed|FAILED)" && \
       ! echo "$LINT_OUTPUT" | grep -q "0 errors"; then
        return 1
    else
        return 0
    fi
}