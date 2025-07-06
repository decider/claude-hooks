#!/bin/bash

# Live integration test for Claude Code hooks
# This script provides test commands that should be run through Claude Code

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "========================================"
echo "Claude Code Hooks Live Integration Tests"
echo "========================================"
echo ""
echo -e "${YELLOW}This test suite provides commands to run through Claude Code${NC}"
echo -e "${YELLOW}to verify all hooks are working correctly.${NC}"
echo ""

# Function to display test section
test_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to display test case
test_case() {
    local test_name="$1"
    local command="$2"
    local expected="$3"
    
    echo ""
    echo -e "${BLUE}Test: $test_name${NC}"
    echo -e "Command: ${GREEN}$command${NC}"
    echo -e "Expected: ${YELLOW}$expected${NC}"
    echo ""
}

# Create test files
echo "Setting up test environment..."
mkdir -p /tmp/claude-test
cat > /tmp/claude-test/sample.js << 'EOF'
// Sample JavaScript file for testing
function calculateTotal(items) {
    let total = 0;
    for (let i = 0; i < items.length; i++) {
        total += items[i].price * items[i].quantity;
    }
    return total;
}

function formatCurrency(amount) {
    return '$' + amount.toFixed(2);
}
EOF

# Test 1: Package Age Hook
test_section "1. PACKAGE AGE HOOK TESTS"

test_case \
    "Block old package" \
    "npm install left-pad@1.0.0" \
    "Should be BLOCKED with 'Execution stopped by PreToolUse hook'"

test_case \
    "Allow recent package" \
    "npm install commander" \
    "Should SUCCEED and install the package"

test_case \
    "Block old package with yarn" \
    "yarn add moment@2.18.0" \
    "Should be BLOCKED"

# Test 2: Pre-Commit Hook
test_section "2. PRE-COMMIT HOOK TESTS"

test_case \
    "Git commit triggers checks" \
    "git add /tmp/claude-test/sample.js && git commit -m 'Test commit'" \
    "Should run TypeScript/lint checks (may fail if not in git repo)"

# Test 3: Code Quality Hooks (Write)
test_section "3. CODE QUALITY HOOKS - WRITE TESTS"

test_case \
    "Write triggers quality primer" \
    "Write a new file at /tmp/claude-test/long-function.js with a function longer than 20 lines" \
    "Should show Clean Code reminder BEFORE writing"

echo "Example content to write:"
cat << 'EOF'
function veryLongFunction() {
    console.log("Line 1");
    console.log("Line 2");
    console.log("Line 3");
    console.log("Line 4");
    console.log("Line 5");
    console.log("Line 6");
    console.log("Line 7");
    console.log("Line 8");
    console.log("Line 9");
    console.log("Line 10");
    console.log("Line 11");
    console.log("Line 12");
    console.log("Line 13");
    console.log("Line 14");
    console.log("Line 15");
    console.log("Line 16");
    console.log("Line 17");
    console.log("Line 18");
    console.log("Line 19");
    console.log("Line 20");
    console.log("Line 21");
    console.log("Line 22");
}
EOF

# Test 4: Code Quality Hooks (Edit)
test_section "4. CODE QUALITY HOOKS - EDIT TESTS"

test_case \
    "Edit triggers similarity check" \
    "Edit /tmp/claude-test/sample.js and add a duplicate of calculateTotal function" \
    "Should check for similar functions BEFORE edit"

# Test 5: Post-Write Hooks
test_section "5. POST-WRITE HOOK TESTS"

test_case \
    "TypeScript file triggers post-write checks" \
    "Write a TypeScript file at /tmp/claude-test/test.ts with: const x: string = 123;" \
    "Should show TypeScript errors AFTER writing"

# Test 6: Todo Completion Hook
test_section "6. TODO COMPLETION HOOK TESTS"

test_case \
    "Marking todo as completed" \
    "Use TodoWrite to mark a task as completed" \
    "Should trigger pre-completion checks"

# Test 7: Context Updater
test_section "7. CONTEXT UPDATER TESTS"

test_case \
    "Edit triggers context update" \
    "Edit any file in the project" \
    "Should update CLAUDE.md if significant changes detected"

# Cleanup section
test_section "CLEANUP"

echo "To clean up test files, run:"
echo -e "${GREEN}rm -rf /tmp/claude-test${NC}"
echo ""

# Summary
test_section "TEST SUMMARY"

echo "Run each command above through Claude Code and verify:"
echo ""
echo "✓ Package age hook blocks old packages"
echo "✓ Pre-commit hook runs checks before git commits"
echo "✓ Code quality primer shows reminders before writes"
echo "✓ Code similarity check detects duplicates"
echo "✓ Post-write hook validates TypeScript"
echo "✓ Todo completion triggers quality checks"
echo "✓ Context updater maintains documentation"
echo ""
echo -e "${YELLOW}Note: Some hooks may show warnings or errors - this is expected${NC}"
echo -e "${YELLOW}The important thing is that they run at the right time${NC}"