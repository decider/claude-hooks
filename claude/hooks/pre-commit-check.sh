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
    
    # Run TypeScript check
    TS_OUTPUT=$(npx tsc --noEmit 2>&1 || true)
    
    if echo "$TS_OUTPUT" | grep -q "error TS"; then
        echo -e "${RED}❌ TypeScript errors found! Cannot commit.${NC}"
        echo "$TS_OUTPUT"
        echo -e "${YELLOW}Fix these errors before committing.${NC}"
        exit 1
    fi
fi

# Lint check
if [ -f "$PROJECT_ROOT/package.json" ] && grep -q '"lint"' "$PROJECT_ROOT/package.json"; then
    echo "Running linter..."
    
    if ! npm run lint &> /dev/null; then
        echo -e "${RED}❌ Linting errors found!${NC}"
        echo -e "${YELLOW}Run 'npm run lint' to see details.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"

# Log hook completion
log_performance "$HOOK_NAME" $START_TIME
log_hook_end "$HOOK_NAME" 0

exit 0

