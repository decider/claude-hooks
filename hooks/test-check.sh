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

# Run tests
if npm test; then
    echo "✅ Tests passed"
    exit 0
else
    echo "❌ Tests failed" >&2
    exit 2
fi