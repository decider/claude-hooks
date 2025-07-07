#!/bin/bash

# Claude Code Stop Validation Hook
# Prevents Claude from stopping until TypeScript and lint checks pass
# Works with monorepos and single projects automatically

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Initialize
HOOK_NAME="stop-validation"

# Read input from stdin (per Claude Code guidelines)
INPUT=$(cat)

log_hook_start "$HOOK_NAME" "$INPUT"

# Check if stop hook is already active to prevent infinite loops
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    log_info "$HOOK_NAME" "Stop hook already active, allowing stop to prevent infinite loop"
    exit 0
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Arrays to track results
declare -a FAILED_CHECKS=()
declare -a TYPESCRIPT_ERRORS=()
declare -a LINT_ERRORS=()

# Function to find all TypeScript project directories
find_typescript_projects() {
    local dirs=()
    
    # Find all package.json files, excluding node_modules and common build directories
    while IFS= read -r package_file; do
        local dir=$(dirname "$package_file")
        
        # Check if this directory has TypeScript
        if [ -f "$dir/tsconfig.json" ] || grep -q '"typescript"' "$package_file" 2>/dev/null; then
            dirs+=("$dir")
            log_debug "$HOOK_NAME" "Found TypeScript project: $dir"
        fi
    done < <(find . -name "package.json" -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/.next/*" -not -path "*/coverage/*" 2>/dev/null)
    
    echo "${dirs[@]}"
}

# Function to run TypeScript check in a directory
check_typescript() {
    local dir="$1"
    local project_name=$(basename "$dir")
    
    log_info "$HOOK_NAME" "Checking TypeScript in $dir"
    
    cd "$dir" || return 1
    
    # Determine which TypeScript command to use
    local tsc_cmd=""
    if [ -f "package.json" ]; then
        # Check for custom scripts
        if grep -q '"typecheck"' package.json 2>/dev/null; then
            tsc_cmd="npm run typecheck"
        elif grep -q '"type-check"' package.json 2>/dev/null; then
            tsc_cmd="npm run type-check"
        elif grep -q '"tsc"' package.json 2>/dev/null; then
            tsc_cmd="npm run tsc"
        fi
    fi
    
    # Fall back to direct tsc if no script found
    if [ -z "$tsc_cmd" ] && [ -f "tsconfig.json" ]; then
        if command -v tsc &> /dev/null; then
            tsc_cmd="tsc --noEmit"
        elif [ -f "node_modules/.bin/tsc" ]; then
            tsc_cmd="./node_modules/.bin/tsc --noEmit"
        elif command -v npx &> /dev/null; then
            tsc_cmd="npx -y tsc --noEmit"
        fi
    fi
    
    if [ -z "$tsc_cmd" ]; then
        log_warn "$HOOK_NAME" "No TypeScript compiler found for $dir"
        return 0
    fi
    
    # Run TypeScript check
    local output
    output=$($tsc_cmd 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        local error_count=$(echo "$output" | grep -c "error TS" || echo "0")
        TYPESCRIPT_ERRORS+=("$project_name: $error_count errors")
        FAILED_CHECKS+=("TypeScript in $dir")
        
        # Output detailed error to stderr for better visibility
        echo "❌ TypeScript errors in $project_name ($error_count errors):" >&2
        echo "$output" >&2
        echo "" >&2
        
        log_error_context "$HOOK_NAME" "TypeScript compilation failed" "$tsc_cmd" "$output"
        log_error "$HOOK_NAME" "TypeScript failed in $dir with $error_count errors"
        
        # Store first few errors for reporting
        if [ ${#TYPESCRIPT_ERRORS[@]} -lt 5 ]; then
            local sample_errors=$(echo "$output" | grep "error TS" | head -3)
            if [ -n "$sample_errors" ]; then
                TYPESCRIPT_ERRORS+=("Sample from $project_name:")
                while IFS= read -r line; do
                    TYPESCRIPT_ERRORS+=("  $line")
                done <<< "$sample_errors"
            fi
        fi
        
        return 1
    else
        log_info "$HOOK_NAME" "TypeScript passed in $dir"
        return 0
    fi
}

# Function to run lint check in a directory
check_lint() {
    local dir="$1"
    local project_name=$(basename "$dir")
    
    cd "$dir" || return 1
    
    # Check if lint script exists
    if [ -f "package.json" ] && grep -q '"lint"' package.json 2>/dev/null; then
        log_info "$HOOK_NAME" "Running lint in $dir"
        
        # Build file list based on filtering options
        local FILES_TO_LINT=""
        local LINT_CMD="npm run lint"
        
        # If specific files are provided
        if [ -n "$HOOK_FILES" ]; then
            FILES_TO_LINT="$HOOK_FILES"
            echo "Linting specific files in $project_name: $FILES_TO_LINT"
        # If include patterns are provided, find matching files
        elif [ -n "$HOOK_INCLUDE" ]; then
            IFS=',' read -ra PATTERNS <<< "$HOOK_INCLUDE"
            for pattern in "${PATTERNS[@]}"; do
                pattern=$(echo "$pattern" | xargs)  # trim whitespace
                FOUND_FILES=$(find . -name "$pattern" -type f 2>/dev/null | grep -v node_modules | head -100)
                if [ -n "$FOUND_FILES" ]; then
                    FILES_TO_LINT="$FILES_TO_LINT $FOUND_FILES"
                fi
            done
        fi
        
        # Apply exclude patterns if provided
        if [ -n "$HOOK_EXCLUDE" ] && [ -n "$FILES_TO_LINT" ]; then
            IFS=',' read -ra EXCLUDE_PATTERNS <<< "$HOOK_EXCLUDE"
            for pattern in "${EXCLUDE_PATTERNS[@]}"; do
                pattern=$(echo "$pattern" | xargs)  # trim whitespace
                FILES_TO_LINT=$(echo "$FILES_TO_LINT" | tr ' ' '\n' | grep -v "$pattern" | tr '\n' ' ')
            done
        fi
        
        local output
        local exit_code
        
        # Run lint command with filtered files
        if [ -n "$FILES_TO_LINT" ]; then
            # Trim whitespace and convert to array
            FILES_TO_LINT=$(echo "$FILES_TO_LINT" | xargs)
            if [ -n "$FILES_TO_LINT" ]; then
                output=$(npm run lint -- $FILES_TO_LINT 2>&1)
                exit_code=$?
            else
                echo "No files to lint after filtering in $project_name."
                return 0
            fi
        else
            # No filtering - run on all files (default behavior)
            output=$(npm run lint 2>&1)
            exit_code=$?
        fi
        
        if [ $exit_code -ne 0 ]; then
            LINT_ERRORS+=("$project_name: lint failed")
            FAILED_CHECKS+=("Lint in $dir")
            
            # Output detailed error to stderr for better visibility
            echo "❌ Lint errors in $project_name:" >&2
            echo "$output" >&2
            echo "" >&2
            
            log_error_context "$HOOK_NAME" "Lint check failed" "$LINT_CMD" "$output"
            log_error "$HOOK_NAME" "Lint failed in $dir"
            return 1
        else
            log_info "$HOOK_NAME" "Lint passed in $dir"
            return 0
        fi
    else
        log_debug "$HOOK_NAME" "No lint script found in $dir"
        return 0
    fi
}

# Main validation logic
main() {
    local original_dir=$(pwd)
    local all_passed=true
    
    # Find all TypeScript projects
    local typescript_projects=($(find_typescript_projects))
    
    if [ ${#typescript_projects[@]} -eq 0 ]; then
        log_info "$HOOK_NAME" "No TypeScript projects found, allowing stop"
        log_hook_end "$HOOK_NAME" 0
        exit 0
    fi
    
    log_info "$HOOK_NAME" "Found ${#typescript_projects[@]} TypeScript project(s) to validate"
    
    # Check each project
    for project_dir in "${typescript_projects[@]}"; do
        cd "$original_dir"
        
        # Run TypeScript check
        if ! check_typescript "$project_dir"; then
            all_passed=false
        fi
        
        cd "$original_dir"
        
        # Run lint check
        if ! check_lint "$project_dir"; then
            all_passed=false
        fi
    done
    
    cd "$original_dir"
    
    # Prepare response based on results
    if [ "$all_passed" = true ]; then
        log_info "$HOOK_NAME" "All validation checks passed"
        log_decision "$HOOK_NAME" "allow" "All TypeScript and lint checks passed"
        
        # No output needed for success (exit code 0 allows stop)
        log_hook_end "$HOOK_NAME" 0
        exit 0
    else
        log_error "$HOOK_NAME" "Validation failed: ${#FAILED_CHECKS[@]} check(s) failed"
        log_decision "$HOOK_NAME" "block" "TypeScript or lint errors must be fixed"
        
        # Build error summary
        local error_summary="Failed checks:\\n"
        for check in "${FAILED_CHECKS[@]}"; do
            error_summary+="- $check\\n"
        done
        
        if [ ${#TYPESCRIPT_ERRORS[@]} -gt 0 ]; then
            error_summary+="\\nTypeScript errors:\\n"
            for error in "${TYPESCRIPT_ERRORS[@]}"; do
                error_summary+="$error\\n"
            done
        fi
        
        if [ ${#LINT_ERRORS[@]} -gt 0 ]; then
            error_summary+="\\nLint errors:\\n"
            for error in "${LINT_ERRORS[@]}"; do
                error_summary+="- $error\\n"
            done
        fi
        
        # Return block response (per Claude Code guidelines)
        cat << EOF
{
  "decision": "block",
  "reason": "Code validation failed. Fix these errors before stopping:\n$error_summary\nRun 'npm run typecheck' and 'npm run lint' in each project to see all errors."
}
EOF
        
        log_hook_end "$HOOK_NAME" 2
        exit 2  # Block Claude from stopping
    fi
}

# Run main validation
main