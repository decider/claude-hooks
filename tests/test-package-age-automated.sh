#!/bin/bash

# Automated test suite for package age hook
# Runs tests directly without manual Claude Code interaction

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_hook() {
    local test_name="$1"
    local command="$2"
    local expected_exit_code="$3"
    local expected_output_pattern="$4"
    
    ((TESTS_RUN++))
    
    echo -e "\n${BLUE}Test $TESTS_RUN: $test_name${NC}"
    echo "Command: $command"
    
    # Create hook input
    local hook_input=$(cat <<EOF
{
  "session_id": "test-$$",
  "transcript_path": "/tmp/test-$$.jsonl",
  "tool_name": "Bash",
  "tool_input": {
    "command": "$command",
    "description": "Test: $test_name"
  }
}
EOF
)
    
    # Run the hook and capture output and exit code
    local output
    local exit_code
    
    output=$(echo "$hook_input" | "$PWD/claude/hooks/check-package-age.sh" 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}
    
    # Check exit code
    local exit_code_pass=false
    if [ "$exit_code" -eq "$expected_exit_code" ]; then
        exit_code_pass=true
        echo -e "  Exit code: ${GREEN}$exit_code (expected)${NC}"
    else
        echo -e "  Exit code: ${RED}$exit_code (expected: $expected_exit_code)${NC}"
    fi
    
    # Check output pattern if provided
    local output_pass=true
    if [ -n "$expected_output_pattern" ]; then
        if echo "$output" | grep -q "$expected_output_pattern"; then
            echo -e "  Output: ${GREEN}Contains expected pattern${NC}"
        else
            output_pass=false
            echo -e "  Output: ${RED}Missing expected pattern: $expected_output_pattern${NC}"
            echo "  Actual output:"
            echo "$output" | sed 's/^/    /'
        fi
    fi
    
    # Overall test result
    if [ "$exit_code_pass" = true ] && [ "$output_pass" = true ]; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        ((TESTS_FAILED++))
    fi
}

echo "========================================"
echo "Package Age Hook Automated Test Suite"
echo "========================================"

# Test 1: Old npm package should be blocked
test_hook \
    "Block old npm package (left-pad@1.0.0)" \
    "npm install left-pad@1.0.0" \
    2 \
    "too old"

# Test 2: Recent package should pass
test_hook \
    "Allow recent npm package" \
    "npm install commander" \
    0 \
    ""

# Test 3: Old yarn package should be blocked
test_hook \
    "Block old yarn package" \
    "yarn add moment@2.18.0" \
    2 \
    "too old"

# Test 4: Non-npm/yarn commands should pass
test_hook \
    "Allow non-package commands" \
    "ls -la" \
    0 \
    ""

# Test 5: npm ci should pass
test_hook \
    "Allow npm ci" \
    "npm ci" \
    0 \
    ""

# Test 6: Git URL should pass
test_hook \
    "Allow git URL packages" \
    "npm install git+https://github.com/user/repo.git" \
    0 \
    ""

# Test 7: Local path should pass
test_hook \
    "Allow local path packages" \
    "npm install ./local-package" \
    0 \
    ""

# Test 8: Multiple packages with one old should block
test_hook \
    "Block when one package is old" \
    "npm install lodash left-pad@1.0.0 commander" \
    2 \
    "left-pad@1.0.0 is too old"

# Test 9: npm install with flags
test_hook \
    "Handle npm install with flags" \
    "npm install --save-dev left-pad@1.0.0" \
    2 \
    "too old"

# Test 10: Tool name filtering
echo -e "\n${BLUE}Test $((++TESTS_RUN)): Non-Bash tool should be ignored${NC}"
hook_input=$(cat <<EOF
{
  "session_id": "test-$$",
  "transcript_path": "/tmp/test-$$.jsonl",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "test.js",
    "content": "npm install left-pad@1.0.0"
  }
}
EOF
)

if echo "$hook_input" | "$PWD/claude/hooks/check-package-age.sh" 2>&1; then
    echo -e "  ${GREEN}✓ PASSED${NC}"
    ((TESTS_PASSED++))
else
    echo -e "  ${RED}✗ FAILED${NC}"
    ((TESTS_FAILED++))
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total tests: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi