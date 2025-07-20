#!/bin/bash

# Comment Ratio Check Module
# Warns if code has too many comments (code should be self-documenting)

check_comment_ratio() {
    local file="$1"
    local max_ratio="${2:-0.2}"  # 20% default
    
    local total_lines=0
    local comment_lines=0
    local in_block_comment=false
    
    while IFS= read -r line; do
        # Skip empty lines
        if [[ -z "${line// }" ]]; then
            continue
        fi
        
        ((total_lines++))
        
        # Check for block comment start
        if [[ "$line" =~ /\* ]] && [[ ! "$line" =~ \*/ ]]; then
            in_block_comment=true
        fi
        
        # Count comment lines
        if [[ "$in_block_comment" == true ]] || \
           [[ "$line" =~ ^[[:space:]]*// ]] || \
           [[ "$line" =~ ^[[:space:]]*# ]] || \
           [[ "$line" =~ ^[[:space:]]*/\* ]] || \
           [[ "$line" =~ ^[[:space:]]*\* ]]; then
            ((comment_lines++))
        fi
        
        # Check for block comment end
        if [[ "$line" =~ \*/ ]]; then
            in_block_comment=false
        fi
    done < "$file"
    
    if [[ $total_lines -eq 0 ]]; then
        return 0
    fi
    
    # Calculate ratio
    local ratio=$(awk "BEGIN {printf \"%.2f\", $comment_lines / $total_lines}")
    
    # Check if ratio exceeds threshold
    if (( $(awk "BEGIN {print ($ratio > $max_ratio)}") )); then
        local percentage=$(awk "BEGIN {printf \"%.0f\", $ratio * 100}")
        echo "Comment ratio violation in $file:"
        echo "  ${percentage}% comments (${comment_lines}/${total_lines} lines)"
        echo "  Consider making code more self-documenting"
        return 1
    fi
    
    return 0
}