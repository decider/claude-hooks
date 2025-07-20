#!/bin/bash

# Function Length Check Module
# Checks that functions don't exceed maximum line count

check_function_length() {
    local file="$1"
    local max_lines="${2:-20}"
    local violations=()
    
    # Only check JS/TS files
    if [[ ! "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
        return 0
    fi
    
    local in_function=false
    local function_start=0
    local function_name=""
    local brace_count=0
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Detect function start (various patterns)
        if [[ "$line" =~ ^[[:space:]]*(function|const|let|var|export|async)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*(\(|=.*\(|=.*async.*\() ]] || \
           [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(\(|async.*\() ]]; then
            if [[ ! "$in_function" == true ]]; then
                function_name="${BASH_REMATCH[2]:-unknown}"
                function_start=$line_num
                in_function=true
                brace_count=0
            fi
        fi
        
        # Count braces
        if [[ "$in_function" == true ]]; then
            # Count opening braces
            local opens=$(echo "$line" | grep -o '{' | wc -l)
            # Count closing braces  
            local closes=$(echo "$line" | grep -o '}' | wc -l)
            brace_count=$((brace_count + opens - closes))
            
            # Function end when brace count returns to 0
            if [[ $brace_count -eq 0 ]] && [[ "$line" =~ \} ]]; then
                local function_length=$((line_num - function_start + 1))
                if [[ $function_length -gt $max_lines ]]; then
                    violations+=("Function '$function_name' at line $function_start: $function_length lines (max: $max_lines)")
                fi
                in_function=false
            fi
        fi
    done < "$file"
    
    # Output violations
    if [[ ${#violations[@]} -gt 0 ]]; then
        echo "Function length violations in $file:"
        printf '%s\n' "${violations[@]}"
        return 1
    fi
    
    return 0
}