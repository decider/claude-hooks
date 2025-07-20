#!/bin/bash
# Test Hook: Always Blocks with JSON Output
# This hook demonstrates the blocking mechanism with continue: false

echo "🚫 TEST BLOCKER HOOK ACTIVATED" >&2

# Read input from stdin
INPUT=$(cat)
EVENT_TYPE=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null)

echo "Event: $EVENT_TYPE, Tool: $TOOL_NAME, File: $FILE_PATH" >&2

# Always output JSON that blocks execution
cat <<EOF
{
  "continue": false,
  "stopReason": "🛑 TEST BLOCKER: This hook always blocks to demonstrate the mechanism",
  "decision": "block",
  "reason": "This is a test hook that demonstrates blocking. To proceed:\n1. Remove this test hook from your configuration\n2. Or disable it temporarily\n\nThis proves that hooks can stop Claude from continuing."
}
EOF

echo "✅ JSON output sent - should block with exit 0" >&2
exit 0