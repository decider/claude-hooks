#!/bin/bash

# Magic Numbers Check Module
# Detects hardcoded numeric literals that should be constants

check_magic_numbers() {
    local file="$1"
    local violations=()
    local line_num=0
    
    # Skip non-code files
    if [[ ! "$file" =~ \.(ts|tsx|js|jsx|py|rs|go|java)$ ]]; then
        return 0
    fi
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip comments
        if [[ "$line" =~ ^[[:space:]]*// ]] || [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*/\* ]]; then
            continue
        fi
        
        # Skip lines with const/let/var declarations (these are defining constants)
        if [[ "$line" =~ (const|let|var|final|static)[[:space:]] ]]; then
            continue
        fi
        
        # Find numbers (excluding 0, 1, -1, and common cases)
        # Exclude: hex colors (#fff), percentages (100%), array indices [0]
        if echo "$line" | grep -qE '[^#\[\.0-9a-fA-F]([2-9]|[1-9][0-9]+)(?![0-9]*[%\]])' && \
           ! echo "$line" | grep -qE '(import|from|require|test|describe|it)\s'; then
            
            # Extract the number
            local numbers=$(echo "$line" | grep -oE '[^#\[\.0-9a-fA-F]([2-9]|[1-9][0-9]+)' | grep -oE '[0-9]+')
            
            for num in $numbers; do
                # Skip common port numbers, HTTP codes, dates
                if [[ "$num" == "200" ]] || [[ "$num" == "404" ]] || [[ "$num" == "500" ]] || \
                   [[ "$num" == "3000" ]] || [[ "$num" == "8080" ]] || [[ "$num" == "2023" ]] || \
                   [[ "$num" == "2024" ]] || [[ "$num" == "2025" ]]; then
                    continue
                fi
                
                violations+=("Line $line_num: Magic number '$num' - consider extracting to a named constant")
            done
        fi
    done < "$file"
    
    # Output violations (max 5)
    if [[ ${#violations[@]} -gt 0 ]]; then
        echo "Magic number violations in $file:"
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