#!/bin/bash

# Code Quality Checks Loader
# Sources all modular check functions

QUALITY_CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/checks"

# Source all check modules
source "$QUALITY_CHECKS_DIR/file-length.sh"
source "$QUALITY_CHECKS_DIR/function-length.sh"
source "$QUALITY_CHECKS_DIR/nesting-depth.sh"
source "$QUALITY_CHECKS_DIR/line-length.sh"
source "$QUALITY_CHECKS_DIR/magic-numbers.sh"
source "$QUALITY_CHECKS_DIR/comment-ratio.sh"
# source "$QUALITY_CHECKS_DIR/duplication.sh" # Removed - broken implementation

# Run all code quality checks
run_all_quality_checks() {
    local file="$1"
    local rules_file="$2"
    local total_violations=0
    
    # Load rules from config if available
    if [[ -f "$rules_file" ]]; then
        MAX_FUNCTION_LINES=$(jq -r '.rules.maxFunctionLines // 20' "$rules_file")
        MAX_FILE_LINES=$(jq -r '.rules.maxFileLines // 100' "$rules_file")
        MAX_NESTING=$(jq -r '.rules.maxNestingDepth // 3' "$rules_file")
        MAX_LINE_LENGTH=$(jq -r '.rules.maxLineLength // 100' "$rules_file")
    else
        # Default values
        MAX_FUNCTION_LINES=20
        MAX_FILE_LINES=100
        MAX_NESTING=3
        MAX_LINE_LENGTH=100
    fi
    
    # Run each check
    if ! check_file_length "$file" "$MAX_FILE_LINES"; then
        ((total_violations++))
    fi
    
    if ! check_function_length "$file" "$MAX_FUNCTION_LINES"; then
        ((total_violations++))
    fi
    
    if ! check_nesting_depth "$file" "$MAX_NESTING"; then
        ((total_violations++))
    fi
    
    if ! check_line_length "$file" "$MAX_LINE_LENGTH"; then
        ((total_violations++))
    fi
    
    if ! check_magic_numbers "$file"; then
        ((total_violations++))
    fi
    
    if ! check_comment_ratio "$file"; then
        ((total_violations++))
    fi
    
    # Duplication check removed - implementation was broken
    
    return $total_violations
}