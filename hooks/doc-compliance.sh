#!/bin/bash

# Doc Compliance Hook - Check documentation standards for all markdown files at session end

source "$(dirname "$0")/common/logging.sh"

log_info "doc-compliance" "Checking documentation compliance for markdown files"

# Find all markdown files in the current directory and subdirectories
MD_FILES=$(find . -name "*.md" -type f 2>/dev/null | grep -v node_modules | grep -v ".git" | sort)

if [ -z "$MD_FILES" ]; then
  log_info "doc-compliance" "No markdown files found to check"
  exit 0
fi

# Track overall compliance
TOTAL_FILES=0
FAILED_FILES=0
ALL_ERRORS=()

# Check each markdown file
while IFS= read -r FILE_PATH; do
  TOTAL_FILES=$((TOTAL_FILES + 1))
  
  # Skip if file doesn't exist (in case it was deleted)
  if [ ! -f "$FILE_PATH" ]; then
    continue
  fi
  
  # Read the file content
  CONTENT=$(cat "$FILE_PATH")
  FILE_ERRORS=()
  
  # Check for README files
  if [[ "$FILE_PATH" =~ README\.md$ ]]; then
    # README should have certain sections
    if ! echo "$CONTENT" | grep -q "^#\|^##"; then
      FILE_ERRORS+=("README.md must have at least one heading")
    fi
    
    if ! echo "$CONTENT" | grep -qi "overview\|description\|about"; then
      FILE_ERRORS+=("README.md should have an Overview or Description section")
    fi
  fi
  
  # Check for API documentation
  if [[ "$FILE_PATH" =~ api.*\.md$ ]] || [[ "$FILE_PATH" =~ .*api\.md$ ]]; then
    if ! echo "$CONTENT" | grep -qi "endpoint\|method\|request\|response"; then
      FILE_ERRORS+=("API documentation should include endpoint details")
    fi
  fi
  
  # General markdown quality checks
  # Check for empty headings
  if echo "$CONTENT" | grep -E "^#+\s*$" > /dev/null; then
    FILE_ERRORS+=("Empty headings found")
  fi
  
  # Check for broken markdown links
  if echo "$CONTENT" | grep -E "\[.*\]\(\s*\)" > /dev/null; then
    FILE_ERRORS+=("Empty markdown links found")
  fi
  
  # Check for TODO/FIXME items
  TODO_COUNT=$(echo "$CONTENT" | grep -ci "todo\|fixme" || true)
  if [ "$TODO_COUNT" -gt 0 ]; then
    FILE_ERRORS+=("Contains $TODO_COUNT TODO/FIXME items")
  fi
  
  # If there are errors for this file, track them
  if [ ${#FILE_ERRORS[@]} -gt 0 ]; then
    FAILED_FILES=$((FAILED_FILES + 1))
    ALL_ERRORS+=("$FILE_PATH:")
    for error in "${FILE_ERRORS[@]}"; do
      ALL_ERRORS+=("  • $error")
    done
    ALL_ERRORS+=("")
  fi
done <<< "$MD_FILES"

# Report results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Documentation Compliance Check Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Checked $TOTAL_FILES markdown files"

if [ $FAILED_FILES -eq 0 ]; then
  echo "✅ All markdown files pass documentation standards!"
  log_info "doc-compliance" "All $TOTAL_FILES markdown files passed compliance check"
else
  echo "❌ $FAILED_FILES file(s) have documentation issues:"
  echo ""
  for error in "${ALL_ERRORS[@]}"; do
    echo "$error"
  done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "💡 Consider fixing these issues to improve documentation quality"
  
  log_warn "doc-compliance" "$FAILED_FILES of $TOTAL_FILES markdown files failed compliance check"
fi