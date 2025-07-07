#!/bin/bash

# Single purpose lint checker
# Just runs linting - nothing else

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/validation.sh"

PROJECT_DIR="${PROJECT_DIR:-.}"

# Check if lint is available
if ! has_lint_script "$PROJECT_DIR"; then
    echo "No lint script found in package.json"
    exit 0
fi

# Build file list (supports staged files if CHECK_STAGED is set)
FILES_TO_LINT=$(build_lint_file_list "$PROJECT_DIR" "$HOOK_FILES" "$HOOK_INCLUDE" "$HOOK_EXCLUDE" "${CHECK_STAGED:-false}")

# Run lint
if run_lint_check "$PROJECT_DIR" "$FILES_TO_LINT"; then
    echo "✅ Lint check passed"
    exit 0
else
    echo "❌ Lint errors found" >&2
    [ -n "$LINT_OUTPUT" ] && echo "$LINT_OUTPUT" >&2
    exit 2
fi