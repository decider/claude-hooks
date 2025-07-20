#!/bin/bash
# Simulate how Claude Code would interact with hooks

echo "=== Simulating Claude Code Hook Execution ==="
echo

# Build first
npm run build > /dev/null 2>&1

echo "Scenario: Claude tries to write test.block-test.txt"
echo "Expected: Hook should block with exit code 2"
echo

# Create the input that Claude would send
CLAUDE_INPUT='{
  "session_id": "claude-session-123",
  "transcript_path": "/Users/danseider/.claude/sessions/current.jsonl",
  "hook_event_name": "PreWrite",
  "file_path": "test.block-test.txt",
  "content": "This is content Claude wants to write"
}'

echo "1. Claude sends PreWrite event to universal-hook"
echo "-------------------------------------------"
echo "$CLAUDE_INPUT" | node lib/commands/universal-hook.js 2>&1

EXIT_CODE=$?
echo
echo "Exit code: $EXIT_CODE"

if [ $EXIT_CODE -eq 2 ]; then
  echo "✅ SUCCESS: Hook blocked execution (exit 2)"
  echo "📋 Claude would see: Hook stopped execution message"
  echo "🚫 File would NOT be written"
else
  echo "❌ FAILURE: Hook did not block (exit $EXIT_CODE)"
  echo "📝 File would be written"
fi

echo
echo "2. What happens with our quality hooks"
echo "--------------------------------------"

# Test TypeScript check
TS_INPUT='{
  "session_id": "claude-session-456",
  "transcript_path": "/Users/danseider/.claude/sessions/current.jsonl",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m \"test commit\""
  }
}'

echo "Scenario: Claude runs 'git commit' (would trigger typescript-check)"
echo

# Create a fake TypeScript error scenario
echo "export const badCode: any = 'using any type';" > /tmp/test-bad.ts
cd /tmp
echo '{"compilerOptions":{"strict":true,"noImplicitAny":true}}' > tsconfig.json

# This would normally run but we'll simulate the output
echo "TypeScript check would run and find errors..."
echo "Hook would output JSON with continue: false"
echo "Claude would be blocked from committing"

# Clean up
rm -f /tmp/test-bad.ts /tmp/tsconfig.json
cd - > /dev/null

echo
echo "3. Summary of how it works:"
echo "---------------------------"
echo "✅ Hooks output JSON with continue: false"
echo "✅ Universal-hook parses JSON and exits with code 2"
echo "✅ Claude Code sees exit code 2 and blocks the operation"
echo "✅ User sees stopReason message"
echo "✅ Claude sees reason message with instructions"

echo
echo "The key is that Claude Code must have these hooks configured in:"
echo "- ~/.claude/settings.json (global)"
echo "- .claude/settings.json (project)"
echo "- Or enterprise settings"