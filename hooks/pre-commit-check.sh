#!/bin/bash


# Source logging library
HOOK_NAME="pre-commit-check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Log hook start
log_hook_start "$HOOK_NAME" "Hook invoked"

# Pre-commit check hook for Claude Code
# Runs before git commit to ensure code quality

PROJECT_ROOT="$(pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔍 Running pre-commit checks...${NC}"

# TypeScript check
if [ -f "$PROJECT_ROOT/package.json" ] && grep -q "typescript" "$PROJECT_ROOT/package.json"; then
    echo "Checking TypeScript types..."
    
    # Build TypeScript command with filtering
    TS_CMD="npx tsc --noEmit"
    
    # If exclude patterns are provided, skip TypeScript check for excluded directories
    if [ -n "$HOOK_EXCLUDE" ]; then
        # Check if we should skip TypeScript check entirely based on exclude patterns
        IFS=',' read -ra EXCLUDE_PATTERNS <<< "$HOOK_EXCLUDE"
        SKIP_TS_CHECK=false
        
        # For monorepo - if we're excluding certain apps, only check specific ones
        if [ -n "$HOOK_INCLUDE" ]; then
            # Run TypeScript only on included paths
            echo "Running TypeScript check on included paths: $HOOK_INCLUDE"
            TS_OUTPUT=""
            IFS=',' read -ra INCLUDE_PATTERNS <<< "$HOOK_INCLUDE"
            for pattern in "${INCLUDE_PATTERNS[@]}"; do
                pattern=$(echo "$pattern" | xargs | sed 's/\*\*$//')  # trim whitespace and trailing **
                if [ -d "$pattern" ] && [ -f "$pattern/tsconfig.json" ]; then
                    echo "Checking TypeScript in $pattern..."
                    PATTERN_OUTPUT=$(cd "$pattern" && npx tsc --noEmit 2>&1 || true)
                    if [ -n "$PATTERN_OUTPUT" ]; then
                        TS_OUTPUT="$TS_OUTPUT$PATTERN_OUTPUT"
                    fi
                fi
            done
        else
            # Run default TypeScript check
            TS_OUTPUT=$(npx tsc --noEmit 2>&1 || true)
            
            # Filter out errors from excluded paths
            FILTERED_OUTPUT=""
            while IFS= read -r line; do
                SHOULD_INCLUDE=true
                for pattern in "${EXCLUDE_PATTERNS[@]}"; do
                    pattern=$(echo "$pattern" | xargs)  # trim whitespace
                    if echo "$line" | grep -q "$pattern"; then
                        SHOULD_INCLUDE=false
                        break
                    fi
                done
                if [ "$SHOULD_INCLUDE" = true ]; then
                    FILTERED_OUTPUT="$FILTERED_OUTPUT$line
"
                fi
            done <<< "$TS_OUTPUT"
            TS_OUTPUT="$FILTERED_OUTPUT"
        fi
    else
        # No filtering - run TypeScript check normally
        TS_OUTPUT=$(npx tsc --noEmit 2>&1 || true)
    fi
    
    if echo "$TS_OUTPUT" | grep -q "error TS"; then
        echo -e "${RED}❌ TypeScript errors found! Cannot commit.${NC}" >&2
        echo "$TS_OUTPUT" >&2
        echo -e "${YELLOW}Fix these errors before committing.${NC}" >&2
        
        # Also log to hook logs with enhanced context
        log_error_context "$HOOK_NAME" "TypeScript compilation failed" "$TS_CMD" "$TS_OUTPUT"
        log_error "$HOOK_NAME" "TypeScript errors found"
        log_decision "$HOOK_NAME" "block" "TypeScript compilation failed"
        log_hook_end "$HOOK_NAME" 1
        exit 1
    fi
fi

# Lint check
if [ -f "$PROJECT_ROOT/package.json" ] && grep -q '"lint"' "$PROJECT_ROOT/package.json"; then
    echo "Running linter..."
    
    # Prepare lint command with file filtering
    LINT_CMD="npm run lint"
    
    # Build file list based on filtering options
    FILES_TO_LINT=""
    
    # If specific files are provided
    if [ -n "$HOOK_FILES" ]; then
        FILES_TO_LINT="$HOOK_FILES"
        echo "Linting specific files: $FILES_TO_LINT"
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
    # For git commits, check staged files
    elif git rev-parse --git-dir > /dev/null 2>&1; then
        STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|vue|svelte)$' | head -50)
        if [ -n "$STAGED_FILES" ]; then
            FILES_TO_LINT="$STAGED_FILES"
            echo "Linting staged files: $FILES_TO_LINT"
        fi
    fi
    
    # Apply exclude patterns if provided
    if [ -n "$HOOK_EXCLUDE" ] && [ -n "$FILES_TO_LINT" ]; then
        IFS=',' read -ra EXCLUDE_PATTERNS <<< "$HOOK_EXCLUDE"
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            pattern=$(echo "$pattern" | xargs)  # trim whitespace
            FILES_TO_LINT=$(echo "$FILES_TO_LINT" | tr ' ' '\n' | grep -v "$pattern" | tr '\n' ' ')
        done
    fi
    
    # Run lint command with filtered files
    if [ -n "$FILES_TO_LINT" ]; then
        # Trim whitespace and convert to array
        FILES_TO_LINT=$(echo "$FILES_TO_LINT" | xargs)
        if [ -n "$FILES_TO_LINT" ]; then
            LINT_OUTPUT=$(npm run lint -- $FILES_TO_LINT 2>&1 || true)
        else
            echo "No files to lint after filtering."
            LINT_OUTPUT=""
        fi
    else
        # No filtering - run on all files (default behavior)
        LINT_OUTPUT=$(npm run lint 2>&1 || true)
    fi
    
    if [ $? -ne 0 ] && [ -n "$LINT_OUTPUT" ]; then
        echo -e "${RED}❌ Linting errors found!${NC}" >&2
        echo "$LINT_OUTPUT" >&2
        echo -e "${YELLOW}Fix linting errors before committing.${NC}" >&2
        
        # Also log to hook logs with enhanced context
        log_error_context "$HOOK_NAME" "Linting failed" "$LINT_CMD" "$LINT_OUTPUT"
        log_error "$HOOK_NAME" "Linting errors found"
        log_decision "$HOOK_NAME" "block" "Linting failed"
        log_hook_end "$HOOK_NAME" 1
        exit 1
    fi
fi

echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"

# Log hook completion
log_performance "$HOOK_NAME" $START_TIME
log_hook_end "$HOOK_NAME" 0

exit 0

