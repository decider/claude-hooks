#!/bin/bash


# Source logging library
HOOK_NAME="pre-completion-check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Log hook start
log_hook_start "$HOOK_NAME" "Hook invoked"

# Pre-completion check hook for Claude Code
# This hook runs before Claude marks tasks as complete to ensure code quality

PROJECT_ROOT="$(pwd)"
HOOK_DIR="$(dirname "$0")"
LOG_FILE="$HOOK_DIR/pre-completion.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

echo -e "${BLUE}🔍 Running pre-completion checks...${NC}"
log "Starting pre-completion checks in $PROJECT_ROOT"

# Track if any checks fail
CHECKS_FAILED=0
ERROR_MESSAGES=""

# Function to add error message
add_error() {
    ERROR_MESSAGES="${ERROR_MESSAGES}\n${RED}❌ $1${NC}"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

# Check 1: TypeScript compilation
if [ -f "$PROJECT_ROOT/package.json" ] && grep -q "typescript" "$PROJECT_ROOT/package.json"; then
    echo -e "${YELLOW}Checking TypeScript types...${NC}"
    
    # Try various TypeScript check commands
    if command -v npm &> /dev/null; then
        if npm run typecheck &> /dev/null 2>&1; then
            echo -e "${GREEN}✓ TypeScript check passed${NC}"
        elif npm run type-check &> /dev/null 2>&1; then
            echo -e "${GREEN}✓ TypeScript check passed${NC}"
        elif npx tsc --noEmit &> /dev/null 2>&1; then
            echo -e "${GREEN}✓ TypeScript check passed${NC}"
        else
            # Capture the actual error output
            TS_ERRORS=$(npx tsc --noEmit 2>&1 || true)
            if echo "$TS_ERRORS" | grep -q "error TS"; then
                add_error "TypeScript errors found:\n$TS_ERRORS"
                log "TypeScript errors: $TS_ERRORS"
            fi
        fi
    fi
fi

# Check 2: Linting
if [ -f "$PROJECT_ROOT/package.json" ]; then
    echo -e "${YELLOW}Checking linting...${NC}"
    
    if npm run lint &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ Linting passed${NC}"
    else
        LINT_OUTPUT=$(npm run lint 2>&1 || true)
        if echo "$LINT_OUTPUT" | grep -qi "error"; then
            add_error "Linting errors found. Run 'npm run lint' to see details."
            log "Linting errors found"
        fi
    fi
fi

# Check 3: Test if tests exist
if [ -f "$PROJECT_ROOT/package.json" ] && grep -q "test" "$PROJECT_ROOT/package.json"; then
    echo -e "${YELLOW}Checking tests...${NC}"
    
    # Only run if test files exist
    if find "$PROJECT_ROOT" -name "*.test.*" -o -name "*.spec.*" | grep -q .; then
        if npm test -- --passWithNoTests &> /dev/null 2>&1; then
            echo -e "${GREEN}✓ Tests passed${NC}"
        else
            add_error "Tests are failing. Run 'npm test' to see details."
            log "Test failures detected"
        fi
    fi
fi

# Check 4: Build check
if [ -f "$PROJECT_ROOT/package.json" ] && grep -q '"build"' "$PROJECT_ROOT/package.json"; then
    echo -e "${YELLOW}Checking build...${NC}"
    
    # Quick build check (not full build)
    if npm run build -- --dry-run &> /dev/null 2>&1 || npm run build &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ Build check passed${NC}"
    else
        BUILD_OUTPUT=$(npm run build 2>&1 || true)
        if echo "$BUILD_OUTPUT" | grep -qi "error"; then
            add_error "Build errors found. Run 'npm run build' to see details."
            log "Build errors found"
        fi
    fi
fi

# Check 5: Git status check
if [ -d "$PROJECT_ROOT/.git" ]; then
    echo -e "${YELLOW}Checking git status...${NC}"
    
    UNSTAGED_CHANGES=$(git diff --name-only | wc -l)
    UNTRACKED_FILES=$(git ls-files --others --exclude-standard | wc -l)
    
    if [ "$UNSTAGED_CHANGES" -gt 0 ]; then
        add_error "You have $UNSTAGED_CHANGES unstaged changes. Consider staging them."
    fi
    
    if [ "$UNTRACKED_FILES" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  You have $UNTRACKED_FILES untracked files${NC}"
    fi
fi

# Check 6: Missing dependencies
if [ -f "$PROJECT_ROOT/package.json" ]; then
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    # Check for common missing dependency patterns in recent errors
    if grep -r "Cannot find module" "$PROJECT_ROOT/src" 2>/dev/null | grep -v node_modules; then
        MISSING_DEPS=$(grep -r "Cannot find module" "$PROJECT_ROOT/src" 2>/dev/null | grep -v node_modules | sed "s/.*Cannot find module '\([^']*\)'.*/\1/" | sort | uniq)
        add_error "Missing dependencies detected:\n$MISSING_DEPS\nRun 'npm install' or install specific packages."
    fi
fi

# Final report
echo -e "\n${BLUE}=== Pre-Completion Check Summary ===${NC}"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Ready to complete task.${NC}"
    log "All checks passed"
    exit 0
else
    echo -e "${RED}❌ $CHECKS_FAILED check(s) failed:${NC}"
    echo -e "$ERROR_MESSAGES"
    echo -e "\n${YELLOW}⚠️  Please fix these issues before marking the task as complete.${NC}"
    log "$CHECKS_FAILED checks failed"
    
    # Block completion
    echo -e "\n${RED}BLOCKING: Task cannot be marked as complete until all checks pass.${NC}"
    exit 2  # Block task completion
fi

