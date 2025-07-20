#!/bin/bash

# TypeScript validation functions
# Simple and focused on TypeScript checks only

# Detect TypeScript command
detect_typescript_command() {
    local dir="${1:-.}"
    
    # Check package.json scripts
    if [ -f "$dir/package.json" ]; then
        if grep -q '"typecheck"' "$dir/package.json" 2>/dev/null; then
            echo "npm run typecheck"
        elif grep -q '"type-check"' "$dir/package.json" 2>/dev/null; then
            echo "npm run type-check"
        elif [ -f "$dir/tsconfig.json" ]; then
            echo "npx -y tsc --noEmit"
        fi
    fi
}

# Run TypeScript check
run_typescript_check() {
    local dir="${1:-.}"
    
    TS_OUTPUT=""
    local tsc_cmd=$(detect_typescript_command "$dir")
    
    if [ -z "$tsc_cmd" ]; then
        return 0  # No TypeScript setup
    fi
    
    TS_OUTPUT=$($tsc_cmd 2>&1 || true)
    
    # Check for errors
    if echo "$TS_OUTPUT" | grep -qE "error TS[0-9]+:"; then
        return 1
    else
        return 0
    fi
}