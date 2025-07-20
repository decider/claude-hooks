#!/bin/bash

# Line Length Check Module
# Checks that lines don't exceed maximum character count

check_line_length() {
    local file="$1"
    local max_length="${2:-80}"
    local violations=()
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip lines that are just long strings or URLs
        if [[ "$line" =~ https?:// ]] || [[ "$line" =~ [\"\'\`].*[\"\'\`] ]]; then
            continue
        fi
        
        local length=${#line}
        if [[ $length -gt $max_length ]]; then
            violations+=("Line $line_num: $length characters (max: $max_length)")
        fi
    done < "$file"
    
    # Output violations (max 5 to avoid spam)
    if [[ ${#violations[@]} -gt 0 ]]; then
        echo "Line length violations in $file:"
        local count=0
        for violation in "${violations[@]}"; do
            echo "  $violation"
            ((count++))
            if [[ $count -ge 5 ]]; then
                if [[ ${#violations[@]} -gt 5 ]]; then
                    echo "  ... and $((${#violations[@]} - 5)) more"
                fi
                break
            fi
        done
        return 1
    fi
    
    return 0
}