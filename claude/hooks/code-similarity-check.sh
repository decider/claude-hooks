#!/bin/bash


# Source logging library
HOOK_NAME="code-similarity-check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Log hook start
log_hook_start "$HOOK_NAME" "Hook invoked"

# Code Similarity Check Utility
# Analyzes code for similarities with existing codebase

set -euo pipefail

# Configuration
SIMILARITY_THRESHOLD="${SIMILARITY_THRESHOLD:-0.8}"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# Function to extract function signatures from TypeScript/JavaScript
extract_ts_functions() {
    local file="$1"
    # Extract function declarations and arrow functions
    grep -E "(export\s+)?(async\s+)?(function\s+\w+|const\s+\w+\s*=\s*(async\s*)?\([^)]*\)\s*=>)" "$file" 2>/dev/null | \
        sed -E 's/^[[:space:]]*//' | \
        sed -E 's/(export|async|function|const|let|var)[[:space:]]+//' | \
        sed -E 's/[[:space:]]*[:=][[:space:]]*\([^)]*\)[[:space:]]*=>.*//' | \
        sed -E 's/\([^)]*\).*//' | \
        tr -d '[:space:]' | \
        sort -u
}

# Function to extract patterns from code
extract_patterns() {
    local content="$1"
    local patterns=()
    
    # Common patterns to detect
    local pattern_checks=(
        "setTimeout.*debounce:debounce implementation"
        "clearTimeout.*debounce:debounce implementation"
        "JSON\.parse.*JSON\.stringify:deep clone pattern"
        "Object\.assign.*\{\}:shallow clone pattern"
        "new Date.*format:date formatting"
        "replace.*[A-Z]:case conversion"
        "map.*filter.*reduce:array chaining"
        "Promise\.all:parallel promises"
        "async.*await.*for:sequential async"
        "try.*catch.*finally:error handling"
    )
    
    for check in "${pattern_checks[@]}"; do
        local pattern="${check%%:*}"
        local description="${check#*:}"
        if echo "$content" | grep -qE "$pattern" 2>/dev/null; then
            patterns+=("$description")
        fi
    done
    
    printf '%s\n' "${patterns[@]}"
}

# Function to calculate similarity score between two strings
calculate_similarity() {
    local str1="$1"
    local str2="$2"
    
    # Simple similarity based on common words
    local words1=$(echo "$str1" | tr -cs '[:alnum:]' '\n' | sort -u)
    local words2=$(echo "$str2" | tr -cs '[:alnum:]' '\n' | sort -u)
    
    local common=$(comm -12 <(echo "$words1") <(echo "$words2") | wc -l)
    local total1=$(echo "$words1" | wc -l)
    local total2=$(echo "$words2" | wc -l)
    
    if [ "$total1" -eq 0 ] || [ "$total2" -eq 0 ]; then
        echo "0"
        return
    fi
    
    # Jaccard similarity coefficient
    local union=$((total1 + total2 - common))
    if [ "$union" -eq 0 ]; then
        echo "0"
    else
        echo "scale=2; $common / $union" | bc
    fi
}

# Function to find similar functions in codebase
find_similar_functions() {
    local new_function="$1"
    local file_type="$2"
    local similar_files=()
    
    # Search for files of the same type
    local search_pattern=""
    case "$file_type" in
        "ts"|"tsx") search_pattern="**/*.{ts,tsx}" ;;
        "js"|"jsx") search_pattern="**/*.{js,jsx}" ;;
        "rs") search_pattern="**/*.rs" ;;
        *) return ;;
    esac
    
    # Find all relevant files (excluding node_modules and common exclusions)
    while IFS= read -r -d '' file; do
        if [[ ! "$file" =~ (node_modules|\.git|dist|build|target) ]]; then
            local existing_functions=$(extract_ts_functions "$file")
            if [ -n "$existing_functions" ]; then
                while IFS= read -r existing; do
                    local similarity=$(calculate_similarity "$new_function" "$existing")
                    if (( $(echo "$similarity > $SIMILARITY_THRESHOLD" | bc -l) )); then
                        similar_files+=("$file:$existing:$similarity")
                    fi
                done <<< "$existing_functions"
            fi
        fi
    done < <(find "$PROJECT_ROOT" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) -print0 2>/dev/null)
    
    # Sort by similarity and output top matches
    printf '%s\n' "${similar_files[@]}" | sort -t: -k3 -rn | head -5
}

# Function to check against common utility libraries
check_utility_libraries() {
    local function_name="$1"
    local suggestions=()
    
    # Common utility mappings
    case "$function_name" in
        *debounce*) suggestions+=("lodash-es: import { debounce } from 'lodash-es'") ;;
        *throttle*) suggestions+=("lodash-es: import { throttle } from 'lodash-es'") ;;
        *camelCase*) suggestions+=("lodash-es: import { camelCase } from 'lodash-es'") ;;
        *snakeCase*) suggestions+=("lodash-es: import { snakeCase } from 'lodash-es'") ;;
        *cloneDeep*|*deepClone*) suggestions+=("lodash-es: import { cloneDeep } from 'lodash-es'") ;;
        *format*Date*) suggestions+=("date-fns: import { format } from 'date-fns'") ;;
        *parse*Date*) suggestions+=("date-fns: import { parse } from 'date-fns'") ;;
        *isValid*) suggestions+=("zod: import { z } from 'zod' // for validation") ;;
    esac
    
    printf '%s\n' "${suggestions[@]}"
}

# Main function
main() {
    local content="${1:-}"
    local file_type="${2:-ts}"
    
    if [ -z "$content" ]; then
        echo "Usage: $0 <content> [file_type]" >&2
        exit 1
    fi
    
    echo "=== Code Similarity Analysis ===" >&2
    
    # Extract patterns
    echo "Detected patterns:" >&2
    local patterns=$(extract_patterns "$content")
    if [ -n "$patterns" ]; then
        echo "$patterns" | sed 's/^/  - /' >&2
    else
        echo "  No common patterns detected" >&2
    fi
    
    # Check for utility library alternatives
    echo -e "\nUtility library suggestions:" >&2
    local function_names=$(echo "$content" | grep -oE '\b\w+\b' | sort -u)
    local found_suggestions=false
    while IFS= read -r func; do
        local suggestions=$(check_utility_libraries "$func")
        if [ -n "$suggestions" ]; then
            echo "$suggestions" | sed 's/^/  - /' >&2
            found_suggestions=true
        fi
    done <<< "$function_names"
    
    if [ "$found_suggestions" = false ]; then
        echo "  No direct utility library matches" >&2
    fi
    
    echo -e "\nSearching for similar functions in codebase..." >&2
    # This would be enhanced with actual AST parsing in production
    echo "  (Full AST analysis would be implemented here)" >&2
}

# Execute if run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

# Log hook completion
log_performance "$HOOK_NAME" $START_TIME
log_hook_end "$HOOK_NAME" 0
