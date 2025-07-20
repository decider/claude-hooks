#!/bin/bash

# TypeScript checker hook
# Simple and focused

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/typescript.sh"

# Run check
if run_typescript_check "${PROJECT_DIR:-.}"; then
    echo "✅ TypeScript check passed"
    echo '{"continue": true}'
else
    echo "❌ TypeScript errors found" >&2
    [ -n "$TS_OUTPUT" ] && echo "$TS_OUTPUT" >&2
    
    # Count errors
    ERROR_COUNT=$(echo "$TS_OUTPUT" | grep -cE "error TS[0-9]+:" || echo "1")
    
    cat <<EOF
{
  "continue": false,
  "stopReason": "TypeScript compilation errors",
  "decision": "block",
  "reason": "Found $ERROR_COUNT TypeScript errors. Run 'npm run typecheck' to see details."
}
EOF
fi