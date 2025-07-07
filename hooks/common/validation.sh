#!/bin/bash

# Common validation functions for TypeScript and linting checks
# This library provides reusable functions to avoid duplication across hooks

# Function to detect the appropriate TypeScript command
detect_typescript_command() {
    local dir="${1:-.}"
    local tsc_cmd=""
    
    # Check for custom scripts in package.json
    if [ -f "$dir/package.json" ]; then
        if grep -q '"typecheck"' "$dir/package.json" 2>/dev/null; then
            tsc_cmd="npm run typecheck"
        elif grep -q '"type-check"' "$dir/package.json" 2>/dev/null; then
            tsc_cmd="npm run type-check"
        elif grep -q '"tsc"' "$dir/package.json" 2>/dev/null; then
            tsc_cmd="npm run tsc"
        fi
    fi
    
    # Fall back to direct tsc if no script found
    if [ -z "$tsc_cmd" ] && [ -f "$dir/tsconfig.json" ]; then
        if command -v tsc &> /dev/null; then
            tsc_cmd="tsc --noEmit"
        elif [ -f "$dir/node_modules/.bin/tsc" ]; then
            tsc_cmd="./node_modules/.bin/tsc --noEmit"
        elif command -v npx &> /dev/null; then
            tsc_cmd="npx -y tsc --noEmit"
        fi
    fi
    
    echo "$tsc_cmd"
}

# Function to run TypeScript check
# Returns: 0 on success, 1 on failure
# Sets: TS_OUTPUT (the output from TypeScript)
#       TS_ERROR_COUNT (number of errors found)
run_typescript_check() {
    local dir="${1:-.}"
    local include_patterns="$2"
    local exclude_patterns="$3"
    
    TS_OUTPUT=""
    TS_ERROR_COUNT=0
    
    # If include patterns are provided and directory-based
    if [ -n "$include_patterns" ]; then
        local all_output=""
        IFS=',' read -ra INCLUDE_PATTERNS <<< "$include_patterns"
        
        for pattern in "${INCLUDE_PATTERNS[@]}"; do
            pattern=$(echo "$pattern" | xargs | sed 's/\*\*$//')  # trim whitespace and trailing **
            
            # Check if it's a directory with its own tsconfig
            if [ -d "$pattern" ] && [ -f "$pattern/tsconfig.json" ]; then
                local tsc_cmd=$(detect_typescript_command "$pattern")
                if [ -n "$tsc_cmd" ]; then
                    local pattern_output=$(cd "$pattern" && $tsc_cmd 2>&1 || true)
                    if [ -n "$pattern_output" ]; then
                        all_output="${all_output}${pattern_output}\n"
                    fi
                fi
            fi
        done
        
        TS_OUTPUT="$all_output"
    else
        # Run TypeScript check in current directory
        local tsc_cmd=$(detect_typescript_command "$dir")
        
        if [ -z "$tsc_cmd" ]; then
            return 0  # No TypeScript setup found
        fi
        
        TS_OUTPUT=$($tsc_cmd 2>&1 || true)
        
        # Apply exclude filtering if needed
        if [ -n "$exclude_patterns" ] && [ -n "$TS_OUTPUT" ]; then
            local filtered_output=""
            IFS=',' read -ra EXCLUDE_PATTERNS <<< "$exclude_patterns"
            
            while IFS= read -r line; do
                local should_include=true
                for pattern in "${EXCLUDE_PATTERNS[@]}"; do
                    pattern=$(echo "$pattern" | xargs)  # trim whitespace
                    if echo "$line" | grep -q "$pattern"; then
                        should_include=false
                        break
                    fi
                done
                if [ "$should_include" = true ]; then
                    filtered_output="${filtered_output}${line}\n"
                fi
            done <<< "$TS_OUTPUT"
            
            TS_OUTPUT="$filtered_output"
        fi
    fi
    
    # Count errors
    TS_ERROR_COUNT=0
    if [ -n "$TS_OUTPUT" ]; then
        TS_ERROR_COUNT=$(echo "$TS_OUTPUT" | grep -E "error TS[0-9]+:" | wc -l | tr -d ' ')
    fi
    
    # Return failure if errors found
    if [ "${TS_ERROR_COUNT:-0}" -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Function to check if lint is available
has_lint_script() {
    local dir="${1:-.}"
    
    if [ -f "$dir/package.json" ] && grep -q '"lint"' "$dir/package.json" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to build file list for linting
build_lint_file_list() {
    local dir="${1:-.}"
    local specific_files="$2"
    local include_patterns="$3"
    local exclude_patterns="$4"
    local check_staged_files="${5:-false}"
    
    local files_to_lint=""
    
    # Priority 1: Specific files provided
    if [ -n "$specific_files" ]; then
        files_to_lint="$specific_files"
    # Priority 2: Include patterns provided
    elif [ -n "$include_patterns" ]; then
        IFS=',' read -ra PATTERNS <<< "$include_patterns"
        for pattern in "${PATTERNS[@]}"; do
            pattern=$(echo "$pattern" | xargs)  # trim whitespace
            local found_files=$(find "$dir" -name "$pattern" -type f 2>/dev/null | grep -v node_modules | head -100)
            if [ -n "$found_files" ]; then
                files_to_lint="$files_to_lint $found_files"
            fi
        done
    # Priority 3: Check staged files for git commits
    elif [ "$check_staged_files" = "true" ] && git rev-parse --git-dir > /dev/null 2>&1; then
        files_to_lint=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|vue|svelte)$' | head -50)
    fi
    
    # Apply exclude patterns if provided
    if [ -n "$exclude_patterns" ] && [ -n "$files_to_lint" ]; then
        IFS=',' read -ra EXCLUDE_PATTERNS <<< "$exclude_patterns"
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            pattern=$(echo "$pattern" | xargs)  # trim whitespace
            files_to_lint=$(echo "$files_to_lint" | tr ' ' '\n' | grep -v "$pattern" | tr '\n' ' ')
        done
    fi
    
    # Trim whitespace
    files_to_lint=$(echo "$files_to_lint" | xargs)
    echo "$files_to_lint"
}

# Function to run lint check
# Returns: 0 on success, 1 on failure
# Sets: LINT_OUTPUT (the output from linting)
run_lint_check() {
    local dir="${1:-.}"
    local files_to_lint="$2"
    
    LINT_OUTPUT=""
    
    if ! has_lint_script "$dir"; then
        return 0  # No lint script found
    fi
    
    # Run lint command
    if [ -n "$files_to_lint" ]; then
        LINT_OUTPUT=$(cd "$dir" && npm run lint -- $files_to_lint 2>&1 || true)
    else
        # No filtering - run on all files (default behavior)
        LINT_OUTPUT=$(cd "$dir" && npm run lint 2>&1 || true)
    fi
    
    # Check if lint failed (non-zero exit code or error patterns in output)
    if echo "$LINT_OUTPUT" | grep -qE "(error|Error|ERROR|failed|Failed|FAILED)" && \
       ! echo "$LINT_OUTPUT" | grep -q "0 errors"; then
        return 1
    else
        return 0
    fi
}

# Function to get TypeScript error summary
get_typescript_error_summary() {
    local output="$1"
    local max_errors="${2:-3}"
    
    # Get unique error types with counts
    local unique_errors=$(echo "$output" | grep -E "error TS[0-9]+:" | sed 's/.*error \(TS[0-9]*\):.*/\1/' | sort | uniq -c | sort -rn | head -5)
    
    # Get first few errors as examples
    local first_errors=$(echo "$output" | grep -E "error TS[0-9]+:" | head -$max_errors)
    
    echo "Top error types:"
    echo "$unique_errors"
    echo ""
    echo "Example errors:"
    echo "$first_errors"
}

# Function to find all TypeScript projects in the current directory tree
find_typescript_projects() {
    local dirs=()
    
    # Find all package.json files, excluding node_modules and common build directories
    while IFS= read -r package_file; do
        local dir=$(dirname "$package_file")
        
        # Check if this directory has TypeScript
        if [ -f "$dir/tsconfig.json" ] || grep -q '"typescript"' "$package_file" 2>/dev/null; then
            dirs+=("$dir")
        fi
    done < <(find . -name "package.json" -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.next/*" -not -path "*/coverage/*" 2>/dev/null)
    
    printf '%s\n' "${dirs[@]}"
}