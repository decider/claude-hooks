#!/bin/bash


# Source logging library
HOOK_NAME="pre-completion-quality-check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Log hook start
log_hook_start "$HOOK_NAME" "Hook invoked"

# Pre-completion Quality Check Hook for Claude Code
# This hook runs linting and tests before allowing task completion
# to prevent committing code with errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENABLE_HOOK="${ENABLE_PRE_COMPLETION_CHECK:-true}"
RUN_TESTS="${RUN_TESTS:-true}"
RUN_LINT="${RUN_LINT:-true}"
RUN_TYPECHECK="${RUN_TYPECHECK:-true}"
STRICT_MODE="${STRICT_MODE:-true}" # If true, any failure blocks completion

# Check if hook is enabled
if [ "$ENABLE_HOOK" != "true" ]; then
    exit 0
fi

# Parse input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# Check if this is a relevant action
if [ "$TOOL_NAME" = "TodoWrite" ]; then
    # Check if any todos are being marked as completed
    COMPLETING=$(echo "$INPUT" | jq -r '.tool_input.todos[]? | select(.status == "completed") | .id' | head -1)
    if [ -z "$COMPLETING" ]; then
        exit 0
    fi
elif [ "$TOOL_NAME" = "Bash" ]; then
    # Check if this is a git commit
    if [[ ! "$COMMAND" =~ ^git[[:space:]]+commit ]]; then
        exit 0
    fi
else
    # Not a relevant tool
    exit 0
fi

echo -e "${BLUE}🔍 Running pre-completion quality checks...${NC}"

# Track if any checks fail
CHECKS_FAILED=0
FAILURE_MESSAGES=()

# Function to run a check and track results
run_check() {
    local check_name="$1"
    local check_command="$2"
    local check_description="$3"
    
    echo -e "${BLUE}Running ${check_description}...${NC}"
    
    if eval "$check_command"; then
        echo -e "${GREEN}✅ ${check_description} passed${NC}"
        return 0
    else
        echo -e "${RED}❌ ${check_description} failed${NC}"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        FAILURE_MESSAGES+=("${check_description} failed")
        return 1
    fi
}

# Change to project root
cd "$PROJECT_ROOT" || exit 0

# Check if this is a Node.js project
if [ -f "package.json" ]; then
    # Check for turbo.json (monorepo)
    if [ -f "turbo.json" ]; then
        echo -e "${BLUE}Detected Turborepo monorepo${NC}"
        
        # Run TypeScript checks
        if [ "$RUN_TYPECHECK" = "true" ]; then
            run_check "typecheck" "npm run typecheck 2>&1" "TypeScript type checking"
        fi
        
        # Run linting
        if [ "$RUN_LINT" = "true" ]; then
            # Build lint command with file filtering
            LINT_CMD="npm run lint"
            if [ -n "$HOOK_FILES" ]; then
                LINT_CMD="npm run lint -- $HOOK_FILES"
            elif [ -n "$HOOK_INCLUDE" ]; then
                # Find files matching include patterns
                FILES_TO_LINT=""
                IFS=',' read -ra PATTERNS <<< "$HOOK_INCLUDE"
                for pattern in "${PATTERNS[@]}"; do
                    pattern=$(echo "$pattern" | xargs)
                    FOUND_FILES=$(find . -name "$pattern" -type f 2>/dev/null | grep -v node_modules | head -100)
                    if [ -n "$FOUND_FILES" ]; then
                        FILES_TO_LINT="$FILES_TO_LINT $FOUND_FILES"
                    fi
                done
                if [ -n "$FILES_TO_LINT" ]; then
                    FILES_TO_LINT=$(echo "$FILES_TO_LINT" | xargs)
                    LINT_CMD="npm run lint -- $FILES_TO_LINT"
                fi
            fi
            
            # Apply exclude patterns
            if [ -n "$HOOK_EXCLUDE" ] && [[ "$LINT_CMD" =~ " -- " ]]; then
                IFS=',' read -ra EXCLUDE_PATTERNS <<< "$HOOK_EXCLUDE"
                for pattern in "${EXCLUDE_PATTERNS[@]}"; do
                    pattern=$(echo "$pattern" | xargs)
                    LINT_CMD=$(echo "$LINT_CMD" | sed "s| [^ ]*${pattern}[^ ]*||g")
                done
            fi
            
            run_check "lint" "$LINT_CMD 2>&1" "ESLint"
        fi
        
        # Run tests
        if [ "$RUN_TESTS" = "true" ] && grep -q '"test"' package.json; then
            run_check "test" "npm run test 2>&1" "Tests"
        fi
    else
        # Regular Node.js project
        echo -e "${BLUE}Detected Node.js project${NC}"
        
        # Check for TypeScript
        if [ "$RUN_TYPECHECK" = "true" ] && [ -f "tsconfig.json" ]; then
            if grep -q '"typecheck"' package.json; then
                run_check "typecheck" "npm run typecheck 2>&1" "TypeScript type checking"
            elif command -v tsc &> /dev/null; then
                run_check "typecheck" "npx tsc --noEmit 2>&1" "TypeScript type checking"
            fi
        fi
        
        # Run linting
        if [ "$RUN_LINT" = "true" ]; then
            if grep -q '"lint"' package.json; then
                # Build lint command with file filtering
                LINT_CMD="npm run lint"
                if [ -n "$HOOK_FILES" ]; then
                    LINT_CMD="npm run lint -- $HOOK_FILES"
                elif [ -n "$HOOK_INCLUDE" ]; then
                    # Find files matching include patterns
                    FILES_TO_LINT=""
                    IFS=',' read -ra PATTERNS <<< "$HOOK_INCLUDE"
                    for pattern in "${PATTERNS[@]}"; do
                        pattern=$(echo "$pattern" | xargs)
                        FOUND_FILES=$(find . -name "$pattern" -type f 2>/dev/null | grep -v node_modules | head -100)
                        if [ -n "$FOUND_FILES" ]; then
                            FILES_TO_LINT="$FILES_TO_LINT $FOUND_FILES"
                        fi
                    done
                    if [ -n "$FILES_TO_LINT" ]; then
                        FILES_TO_LINT=$(echo "$FILES_TO_LINT" | xargs)
                        LINT_CMD="npm run lint -- $FILES_TO_LINT"
                    fi
                fi
                
                # Apply exclude patterns
                if [ -n "$HOOK_EXCLUDE" ] && [[ "$LINT_CMD" =~ " -- " ]]; then
                    IFS=',' read -ra EXCLUDE_PATTERNS <<< "$HOOK_EXCLUDE"
                    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
                        pattern=$(echo "$pattern" | xargs)
                        LINT_CMD=$(echo "$LINT_CMD" | sed "s| [^ ]*${pattern}[^ ]*||g")
                    done
                fi
                
                run_check "lint" "$LINT_CMD 2>&1" "ESLint"
            elif [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f "eslint.config.js" ]; then
                # Build eslint command with file filtering
                ESLINT_CMD="npx eslint ."
                if [ -n "$HOOK_FILES" ]; then
                    ESLINT_CMD="npx eslint $HOOK_FILES"
                elif [ -n "$HOOK_INCLUDE" ]; then
                    # Find files matching include patterns
                    FILES_TO_LINT=""
                    IFS=',' read -ra PATTERNS <<< "$HOOK_INCLUDE"
                    for pattern in "${PATTERNS[@]}"; do
                        pattern=$(echo "$pattern" | xargs)
                        FOUND_FILES=$(find . -name "$pattern" -type f 2>/dev/null | grep -v node_modules | head -100)
                        if [ -n "$FOUND_FILES" ]; then
                            FILES_TO_LINT="$FILES_TO_LINT $FOUND_FILES"
                        fi
                    done
                    if [ -n "$FILES_TO_LINT" ]; then
                        FILES_TO_LINT=$(echo "$FILES_TO_LINT" | xargs)
                        ESLINT_CMD="npx eslint $FILES_TO_LINT"
                    fi
                fi
                
                run_check "lint" "$ESLINT_CMD 2>&1" "ESLint"
            fi
        fi
        
        # Run tests
        if [ "$RUN_TESTS" = "true" ] && grep -q '"test"' package.json; then
            # Skip if test command is just "echo"
            if ! grep -q '"test".*"echo' package.json; then
                run_check "test" "npm test 2>&1" "Tests"
            fi
        fi
    fi
fi

# Check if this is a Python project
if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    echo -e "${BLUE}Detected Python project${NC}"
    
    # Run Python linting
    if [ "$RUN_LINT" = "true" ]; then
        if command -v ruff &> /dev/null; then
            run_check "ruff" "ruff check . 2>&1" "Ruff linting"
        elif command -v flake8 &> /dev/null; then
            run_check "flake8" "flake8 . 2>&1" "Flake8 linting"
        elif command -v pylint &> /dev/null; then
            run_check "pylint" "pylint **/*.py 2>&1" "Pylint"
        fi
    fi
    
    # Run Python type checking
    if [ "$RUN_TYPECHECK" = "true" ] && command -v mypy &> /dev/null; then
        run_check "mypy" "mypy . 2>&1" "MyPy type checking"
    fi
    
    # Run Python tests
    if [ "$RUN_TESTS" = "true" ]; then
        if [ -f "pytest.ini" ] || [ -d "tests" ]; then
            run_check "pytest" "python -m pytest 2>&1" "Pytest"
        elif [ -f "manage.py" ]; then
            run_check "django-test" "python manage.py test 2>&1" "Django tests"
        fi
    fi
fi

# Check if this is a Rust project
if [ -f "Cargo.toml" ]; then
    echo -e "${BLUE}Detected Rust project${NC}"
    
    # Run Rust checks
    if [ "$RUN_TYPECHECK" = "true" ]; then
        run_check "cargo-check" "cargo check 2>&1" "Cargo check"
    fi
    
    if [ "$RUN_LINT" = "true" ]; then
        run_check "cargo-clippy" "cargo clippy -- -D warnings 2>&1" "Cargo clippy"
    fi
    
    if [ "$RUN_TESTS" = "true" ]; then
        run_check "cargo-test" "cargo test 2>&1" "Cargo tests"
    fi
fi

# Summary and decision
echo -e "\n${BLUE}Quality Check Summary:${NC}"
if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All quality checks passed!${NC}"
    
    # Send success notification
    if command -v osascript &> /dev/null; then
        osascript -e 'display notification "All quality checks passed! Ready to complete task." with title "Claude Code" sound name "Glass"' 2>/dev/null || true
    fi
    
    exit 0
else
    echo -e "${RED}❌ ${CHECKS_FAILED} quality check(s) failed:${NC}"
    for msg in "${FAILURE_MESSAGES[@]}"; do
        echo -e "${RED}   - ${msg}${NC}"
    done
    
    # Send failure notification
    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"${CHECKS_FAILED} quality checks failed. Please fix errors before completing.\" with title \"Claude Code\" sound name \"Basso\"" 2>/dev/null || true
    fi
    
    if [ "$STRICT_MODE" = "true" ]; then
        echo -e "\n${YELLOW}⚠️  Task completion blocked due to quality check failures.${NC}" >&2
        echo -e "${YELLOW}Fix the errors above or set STRICT_MODE=false to bypass.${NC}" >&2
        
        # Output JSON response for Claude
        cat <<EOF
{
  "decision": "block",
  "reason": "Quality checks failed: ${FAILURE_MESSAGES[*]}. Please fix the errors before completing the task."
}
EOF
        exit 2  # Exit code 2 blocks the action
    else
        echo -e "\n${YELLOW}⚠️  Quality checks failed but proceeding (STRICT_MODE=false).${NC}"
        exit 0
    fi
fi

