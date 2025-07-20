#!/bin/bash

# Single purpose test runner
# Just runs tests - nothing else

PROJECT_DIR="${PROJECT_DIR:-.}"

# Check if test script exists
if [ ! -f "$PROJECT_DIR/package.json" ] || ! grep -q '"test"' "$PROJECT_DIR/package.json"; then
    echo "No test script found in package.json"
    exit 0
fi

cd "$PROJECT_DIR" || exit 2

# Run tests and capture output
TEST_OUTPUT=$(npm test 2>&1)
TEST_EXIT_CODE=$?

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ Tests passed"
    echo "$TEST_OUTPUT"
    exit 0
else
    echo "❌ Tests failed" >&2
    echo "$TEST_OUTPUT" >&2
    
    # Extract failed test information
    FAILED_COUNT=$(echo "$TEST_OUTPUT" | grep -E "(failing|failed|FAILED)" | grep -oE "[0-9]+" | head -1 || echo "some")
    
    # Extract test names that failed
    FAILED_TESTS=$(echo "$TEST_OUTPUT" | grep -E "(✗|×|FAIL|failing)" | head -5 | sed 's/^[[:space:]]*/• /')
    
    # Check for specific test commands
    TEST_CMD="npm test"
    if grep -q '"test:watch"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        WATCH_CMD="npm run test:watch"
    fi
    
    # Build reason message for Claude
    REASON="$FAILED_COUNT tests are failing. Please fix these test failures:\n\n$FAILED_TESTS\n\nRun '$TEST_CMD' to see full test output."
    if [ -n "$WATCH_CMD" ]; then
        REASON="$REASON\nTip: Use '$WATCH_CMD' for continuous testing while fixing."
    fi
    
    # Output JSON for Claude Code
    cat <<EOF
{
  "continue": false,
  "stopReason": "Tests are failing - cannot proceed",
  "decision": "block",
  "reason": "$REASON"
}
EOF
    exit 0  # Use exit 0 when outputting JSON
fi