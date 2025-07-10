#!/bin/bash

# Doc Compliance Hook - Enforce documentation standards for markdown files

source "$(dirname "$0")/common/logging.sh"

# Check if required environment variables are set
if [ -z "$CLAUDE_TOOL_RESULT_FILE" ]; then
  log_error "doc-compliance" "Missing required CLAUDE_TOOL_RESULT_FILE environment variable"
  exit 1
fi

# Read the tool result
TOOL_RESULT=$(cat "$CLAUDE_TOOL_RESULT_FILE" 2>/dev/null)
if [ -z "$TOOL_RESULT" ]; then
  log_warn "doc-compliance" "Empty tool result file"
  exit 0
fi

# Extract the file path from the tool result
FILE_PATH=$(echo "$TOOL_RESULT" | jq -r '.file_path' 2>/dev/null)
if [ -z "$FILE_PATH" ] || [ "$FILE_PATH" = "null" ]; then
  log_warn "doc-compliance" "Could not extract file path from tool result"
  exit 0
fi

# Only check markdown files
if [[ ! "$FILE_PATH" =~ \.md$ ]]; then
  exit 0
fi

log_info "doc-compliance" "Checking documentation compliance for: $FILE_PATH"

# Skip if file doesn't exist
if [ ! -f "$FILE_PATH" ]; then
  log_warn "doc-compliance" "File not found: $FILE_PATH"
  exit 0
fi

# Read the file content
CONTENT=$(cat "$FILE_PATH")

# Check for required sections based on file type
ERRORS=()

# Check for README files
if [[ "$FILE_PATH" =~ README\.md$ ]]; then
  # README should have certain sections
  if ! echo "$CONTENT" | grep -q "^#\|^##"; then
    ERRORS+=("README.md must have at least one heading")
  fi
  
  if ! echo "$CONTENT" | grep -qi "overview\|description\|about"; then
    ERRORS+=("README.md should have an Overview or Description section")
  fi
fi

# Check for API documentation
if [[ "$FILE_PATH" =~ api.*\.md$ ]] || [[ "$FILE_PATH" =~ .*api\.md$ ]]; then
  if ! echo "$CONTENT" | grep -qi "endpoint\|method\|request\|response"; then
    ERRORS+=("API documentation should include endpoint details")
  fi
fi

# General markdown quality checks
# Check for empty headings
if echo "$CONTENT" | grep -E "^#+\s*$"; then
  ERRORS+=("Empty headings found")
fi

# Check for broken markdown links
if echo "$CONTENT" | grep -E "\[.*\]\(\s*\)"; then
  ERRORS+=("Empty markdown links found")
fi

# Check for TODO/FIXME items
TODO_COUNT=$(echo "$CONTENT" | grep -ci "todo\|fixme" || true)
if [ "$TODO_COUNT" -gt 0 ]; then
  log_warn "doc-compliance" "Found $TODO_COUNT TODO/FIXME items in documentation"
fi

# If there are errors, report them
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "❌ Documentation compliance check failed for $FILE_PATH:"
  echo
  for error in "${ERRORS[@]}"; do
    echo "  • $error"
  done
  echo
  echo "Please fix these issues to ensure documentation quality."
  
  log_error "doc-compliance" "Documentation compliance failed with ${#ERRORS[@]} errors"
  exit 1
fi

log_info "doc-compliance" "Documentation compliance check passed"
echo "✅ Documentation compliance check passed for $FILE_PATH"