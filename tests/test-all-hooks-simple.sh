#!/bin/bash

# Simple test suite for all Claude Code hooks
# This script tests all configured hooks with basic validation

set -uo pipefail
# Note: Removed -e flag to prevent early exit on hook failures during testing

# Export test mode to prevent hooks from blocking during tests
export CLAUDE_HOOKS_TEST_MODE=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "========================================"
echo "Claude Code Hooks Simple Test Suite"
echo "========================================"
echo -e "${YELLOW}Testing all configured hooks${NC}"
echo ""

# Function to run a simple test
simple_test() {
    local test_name="$1"
    local hook_input="$2"
    local expected_exit="$3"
    
    ((TOTAL_TESTS++))
    
    echo -e "${BLUE}Test $TOTAL_TESTS: $test_name${NC}"
    
    # Run the test
    local exit_code=0
    local output=""
    output=$(echo "$hook_input" | claude/hooks/check-package-age.sh 2>&1) || exit_code=$?
    
    # Check result
    local success=false
    if [ "$expected_exit" = "BLOCK" ]; then
        if echo "$output" | grep -q "\[TEST MODE\] Would have blocked"; then
            echo -e "  ${GREEN}✓ Correctly blocked (test mode)${NC}"
            success=true
        elif [ $exit_code -eq 2 ]; then
            echo -e "  ${GREEN}✓ Correctly blocked${NC}"
            success=true
        else
            echo -e "  ${RED}✗ Expected blocking${NC}"
        fi
    elif [ "$expected_exit" = "PASS" ]; then
        if [ $exit_code -eq 0 ]; then
            echo -e "  ${GREEN}✓ Correctly passed${NC}"
            success=true
        else
            echo -e "  ${RED}✗ Expected pass but got exit code $exit_code${NC}"
        fi
    fi
    
    if [ "$success" = true ]; then
        ((PASSED_TESTS++))
    else
        ((FAILED_TESTS++))
        echo -e "  ${YELLOW}Output: $(echo "$output" | head -1)${NC}"
    fi
    
}

# Test 1: Package age hook - old package
simple_test \
    "Block old package (left-pad@1.0.0)" \
    '{"session_id": "test-1", "transcript_path": "/tmp/test-1.jsonl", "hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "npm install left-pad@1.0.0", "description": "Install old package"}}' \
    "BLOCK"

# Test 2: Package age hook - recent package
simple_test \
    "Allow recent package (commander)" \
    '{"session_id": "test-2", "transcript_path": "/tmp/test-2.jsonl", "hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "npm install commander", "description": "Install recent package"}}' \
    "PASS"

# Test 3: Non-npm command
simple_test \
    "Ignore non-npm command" \
    '{"session_id": "test-3", "transcript_path": "/tmp/test-3.jsonl", "hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "ls -la", "description": "List files"}}' \
    "PASS"

# Test 4: Yarn old package
simple_test \
    "Block old yarn package (moment@2.18.0)" \
    '{"session_id": "test-4", "transcript_path": "/tmp/test-4.jsonl", "hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "yarn add moment@2.18.0", "description": "Install old package with yarn"}}' \
    "BLOCK"

# Test 5: Non-Bash tool
simple_test \
    "Ignore non-Bash tool" \
    '{"session_id": "test-5", "transcript_path": "/tmp/test-5.jsonl", "hook_event_name": "PreToolUse", "tool_name": "Write", "tool_input": {"file_path": "/tmp/test.js", "content": "console.log(\"test\")"}}' \
    "PASS"

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the output above.${NC}"
    exit 1
fi