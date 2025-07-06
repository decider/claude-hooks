#!/bin/bash

# Test suite for the package age hook
# This script tests the hook through Claude Code commands

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test results file
TEST_RESULTS="/tmp/package-age-hook-test-results.txt"
TEST_LOG="/tmp/package-age-hook-test.log"

# Clean up function
cleanup() {
    rm -f "$TEST_RESULTS" "$TEST_LOG"
    # Clean up any test packages
    npm uninstall left-pad moment lodash commander 2>/dev/null || true
}

# Run cleanup on exit
trap cleanup EXIT

# Test function
run_test() {
    local test_name="$1"
    local expected_result="$2"
    local test_command="$3"
    
    echo -e "\n${YELLOW}Running test: $test_name${NC}"
    echo "Command: $test_command"
    
    # Clear previous results
    echo "" > "$TEST_RESULTS"
    
    # Run the test command and capture the result
    if eval "$test_command" > "$TEST_LOG" 2>&1; then
        echo "SUCCESS" > "$TEST_RESULTS"
    else
        echo "BLOCKED" > "$TEST_RESULTS"
    fi
    
    local actual_result=$(cat "$TEST_RESULTS")
    
    if [ "$actual_result" = "$expected_result" ]; then
        echo -e "${GREEN}✓ PASSED${NC}: $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}: $test_name"
        echo "  Expected: $expected_result"
        echo "  Actual: $actual_result"
        echo "  Log output:"
        cat "$TEST_LOG" | sed 's/^/    /'
        ((TESTS_FAILED++))
    fi
}

# Function to simulate Claude Code hook execution
simulate_hook() {
    local command="$1"
    local hook_input=$(cat <<EOF
{
  "session_id": "test-session",
  "transcript_path": "/tmp/test-transcript.jsonl",
  "tool_name": "Bash",
  "tool_input": {
    "command": "$command",
    "description": "Test command"
  }
}
EOF
)
    
    echo "$hook_input" | claude/hooks/check-package-age.sh
    return $?
}

echo "========================================"
echo "Package Age Hook Test Suite"
echo "========================================"

# Test 1: Old package should be blocked
run_test "Block old package (left-pad@1.0.0 from 2016)" \
    "BLOCKED" \
    'simulate_hook "npm install left-pad@1.0.0"'

# Test 2: Recent package should be allowed
run_test "Allow recent package (commander latest)" \
    "SUCCESS" \
    'simulate_hook "npm install commander"'

# Test 3: Old package with yarn should be blocked
run_test "Block old package with yarn" \
    "BLOCKED" \
    'simulate_hook "yarn add moment@2.18.0"'

# Test 4: Non-npm commands should be allowed
run_test "Allow non-npm bash commands" \
    "SUCCESS" \
    'simulate_hook "ls -la"'

# Test 5: Package.json edits should be allowed (with notice)
run_test "Allow package.json edits" \
    "SUCCESS" \
    'simulate_hook "edit package.json"'

# Test 6: Multiple packages with one old should block
run_test "Block when one of multiple packages is old" \
    "BLOCKED" \
    'simulate_hook "npm install lodash left-pad@1.0.0"'

# Test 7: Git URLs should be allowed
run_test "Allow git URL packages" \
    "SUCCESS" \
    'simulate_hook "npm install git+https://github.com/user/repo.git"'

# Test 8: Local file paths should be allowed
run_test "Allow local file packages" \
    "SUCCESS" \
    'simulate_hook "npm install ./local-package"'

# Test 9: npm ci should be allowed
run_test "Allow npm ci command" \
    "SUCCESS" \
    'simulate_hook "npm ci"'

# Test 10: Check age threshold (180 days)
# This test would need a package that's between 180-200 days old
# For now, we'll test the threshold is working by checking environment variable
run_test "Respect MAX_AGE_DAYS environment variable" \
    "SUCCESS" \
    'MAX_AGE_DAYS=10000 simulate_hook "npm install left-pad@1.0.0"'

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi