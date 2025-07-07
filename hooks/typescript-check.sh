#!/bin/bash

# Single purpose TypeScript checker
# Just checks TypeScript - nothing else

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/validation.sh"

# Simple and direct
if run_typescript_check "${PROJECT_DIR:-.}" "$HOOK_INCLUDE" "$HOOK_EXCLUDE"; then
    echo "✅ TypeScript check passed"
    exit 0
else
    echo "❌ TypeScript errors found" >&2
    [ -n "$TS_OUTPUT" ] && echo "$TS_OUTPUT" >&2
    exit 2
fi