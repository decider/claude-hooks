#!/bin/bash

# File Length Check Module
# Checks that files don't exceed maximum line count

check_file_length() {
    local file="$1"
    local max_lines="${2:-100}"
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    local line_count=$(wc -l < "$file" | tr -d ' ')
    
    if [[ $line_count -gt $max_lines ]]; then
        echo "File length violation: $file has $line_count lines (max: $max_lines)"
        return 1
    fi
    
    return 0
}