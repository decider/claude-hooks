#!/bin/bash

# Lint checker hook
# Simple and focused

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/linting.sh"

# Run check
if run_lint_check "${PROJECT_DIR:-.}"; then
    echo "✅ Lint check passed"
    echo '{"continue": true}'
else
    echo "❌ Lint errors found" >&2
    [ -n "$LINT_OUTPUT" ] && echo "$LINT_OUTPUT" >&2
    
    cat <<EOF
{
  "continue": false,
  "stopReason": "Code linting errors",
  "decision": "block",
  "reason": "Linting errors detected. Run 'npm run lint' to see details."
}
EOF
fi