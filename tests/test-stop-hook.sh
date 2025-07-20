#!/bin/bash
# Test the stop hook JSON output handling

echo "Testing stop hook with JSON output..."

# Create a test hook that outputs JSON
cat > /tmp/test-stop-hook.sh << 'EOF'
#!/bin/bash
INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')

if [ "$EVENT" = "Stop" ]; then
  cat <<JSON
{
  "continue": false,
  "stopReason": "Test stop reason - this should prevent completion",
  "decision": "block",
  "reason": "Test reason for Claude - fix these imaginary issues"
}
JSON
fi
exit 0
EOF

chmod +x /tmp/test-stop-hook.sh

# Create test input
TEST_INPUT='{
  "session_id": "test-123",
  "transcript_path": "/tmp/test.jsonl",
  "hook_event_name": "Stop",
  "stop_hook_active": false
}'

echo "Test 1: Hook outputs JSON with continue: false"
echo "$TEST_INPUT" | /tmp/test-stop-hook.sh
echo "Exit code: $?"
echo

echo "Test 2: Executing through our universal hook (would need npx context)"
# This would need to be run in the actual Claude Code environment
# echo "$TEST_INPUT" | npx claude-code-hooks-cli exec /tmp/test-stop-hook.sh

echo "Test 3: Testing with our example hooks"
echo "$TEST_INPUT" | ./examples/hooks/stop-on-errors.sh
echo "Exit code: $?"

# Cleanup
rm -f /tmp/test-stop-hook.sh

echo "Tests complete!"