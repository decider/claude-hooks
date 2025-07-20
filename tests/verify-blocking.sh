#!/bin/bash
# Verification script to test hook blocking mechanism

echo "=== Hook Blocking Verification Test ==="
echo

# First, build the TypeScript
echo "Building TypeScript..."
npm run build

echo
echo "Test 1: Direct hook execution test"
echo "--------------------------------"

# Create test input for PreWrite event
TEST_INPUT='{
  "session_id": "test-123",
  "transcript_path": "/tmp/test.jsonl",
  "hook_event_name": "PreWrite",
  "file_path": "test.block-test.txt",
  "content": "This should be blocked"
}'

echo "Sending PreWrite event for test.block-test.txt..."
echo "$TEST_INPUT" | HOOK_DEBUG=1 node lib/commands/universal-hook.js

EXIT_CODE=$?
echo "Exit code: $EXIT_CODE"

if [ $EXIT_CODE -eq 2 ]; then
  echo "✅ Hook successfully blocked with exit code 2"
else
  echo "❌ Hook did not block (exit code: $EXIT_CODE)"
fi

echo
echo "Test 2: Test the test-blocker hook directly"
echo "------------------------------------------"

echo "$TEST_INPUT" | ./hooks/test-blocker.sh
EXIT_CODE=$?
echo "Exit code: $EXIT_CODE"

echo
echo "Test 3: Check hook configuration"
echo "--------------------------------"
echo "Config file: .claude/hooks/config.cjs"
grep -A2 "block-test" .claude/hooks/config.cjs

echo
echo "Test 4: Execute hook via CLI"
echo "----------------------------"
echo "$TEST_INPUT" | npx claude-code-hooks-cli exec test-blocker
EXIT_CODE=$?
echo "Exit code: $EXIT_CODE"

echo
echo "=== Test Summary ==="
echo "If hooks are working correctly:"
echo "- Exit code should be 2 (blocking)"
echo "- JSON output should show continue: false"
echo "- stopReason should be visible"

# Clean up test file if it exists
rm -f test.block-test.txt