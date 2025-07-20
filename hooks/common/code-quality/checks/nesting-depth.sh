#!/bin/bash

# Nesting Depth Check Module
# Checks that code doesn't exceed maximum nesting depth

check_nesting_depth() {
    local file="$1"
    local max_depth="${2:-3}"
    local violations=()
    
    local current_depth=0
    local max_seen=0
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Count opening braces
        local opens=$(echo "$line" | grep -o '{' | wc -l)
        # Count closing braces
        local closes=$(echo "$line" | grep -o '}' | wc -l)
        
        current_depth=$((current_depth + opens))
        
        if [[ $current_depth -gt $max_seen ]]; then
            max_seen=$current_depth
        fi
        
        if [[ $current_depth -gt $max_depth ]]; then
            violations+=("Line $line_num: nesting depth $current_depth exceeds maximum $max_depth")
        fi
        
        current_depth=$((current_depth - closes))
        
        # Ensure depth doesn't go negative
        if [[ $current_depth -lt 0 ]]; then
            current_depth=0
        fi
    done < "$file"
    
    # Output violations
    if [[ ${#violations[@]} -gt 0 ]]; then
        echo "Nesting depth violations in $file:"
        # Show only first 3 violations to avoid spam
        for i in {0..2}; do
            if [[ $i -lt ${#violations[@]} ]]; then
                echo "  ${violations[$i]}"
            fi
        done
        if [[ ${#violations[@]} -gt 3 ]]; then
            echo "  ... and $((${#violations[@]} - 3)) more"
        fi
        return 1
    fi
    
    return 0
}