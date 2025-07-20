#!/bin/bash

# Code Duplication Check Module
# Detects repeated patterns that should be extracted

check_duplication() {
    local file="$1"
    local threshold="${2:-5}"  # Min occurrences to flag
    
    # Only check JS/TS files
    if [[ ! "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
        return 0
    fi
    
    # Track function calls
    declare -A function_calls
    local violations=()
    
    # Extract function calls (simple pattern)
    while IFS= read -r line; do
        # Skip comments
        if [[ "$line" =~ ^[[:space:]]*// ]] || [[ "$line" =~ ^[[:space:]]*/\* ]]; then
            continue
        fi
        
        # Find function calls: word followed by (
        local calls=$(echo "$line" | grep -oE '[a-zA-Z_][a-zA-Z0-9_]*\s*\(' | sed 's/[[:space:]]*(//')
        
        for call in $calls; do
            # Skip common keywords
            if [[ "$call" =~ ^(if|for|while|switch|catch|function|async|await)$ ]]; then
                continue
            fi
            
            ((function_calls["$call"]++))
        done
    done < "$file"
    
    # Check for violations
    for func in "${!function_calls[@]}"; do
        local count=${function_calls[$func]}
        if [[ $count -ge $threshold ]]; then
            violations+=("Function '$func' called $count times - consider extracting to utility")
        fi
    done
    
    # Output violations
    if [[ ${#violations[@]} -gt 0 ]]; then
        echo "Code duplication detected in $file:"
        for violation in "${violations[@]}"; do
            echo "  $violation"
        done
        echo "  Consider extracting repeated logic to reusable functions"
        return 1
    fi
    
    return 0
}