#!/bin/bash

# Portable Code Quality Validator
# Works with TypeScript, JavaScript, Python, Ruby, and more

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read input
INPUT=$(cat)
TOOL=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4) || TOOL=""
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4) || FILE_PATH=""
EVENT_TYPE=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4) || EVENT_TYPE=""

# Configuration
RULES_FILE="${SCRIPT_DIR}/../.claude/hooks/quality-config.json"
LOG_FILE="${SCRIPT_DIR}/../.claude/hooks/code-quality.log"

# Colors (portable)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Log function
log() {
    echo "[$(date)] $1" >> "$LOG_FILE"
}

log "QUALITY VALIDATOR STARTED"
log "Event: $EVENT_TYPE, Tool: $TOOL, File: $FILE_PATH"

# Load configuration
if [[ -f "$RULES_FILE" ]]; then
    MAX_FUNCTION_LINES=$(grep -o '"maxFunctionLines":[^,}]*' "$RULES_FILE" | cut -d':' -f2 | tr -d ' ' || echo "30")
    MAX_FILE_LINES=$(grep -o '"maxFileLines":[^,}]*' "$RULES_FILE" | cut -d':' -f2 | tr -d ' ' || echo "200")
    MAX_LINE_LENGTH=$(grep -o '"maxLineLength":[^,}]*' "$RULES_FILE" | cut -d':' -f2 | tr -d ' ' || echo "100")
    MAX_NESTING=$(grep -o '"maxNestingDepth":[^,}]*' "$RULES_FILE" | cut -d':' -f2 | tr -d ' ' || echo "4")
else
    MAX_FUNCTION_LINES=30
    MAX_FILE_LINES=200
    MAX_LINE_LENGTH=100
    MAX_NESTING=4
fi

# Check file based on extension
check_file() {
    local file="$1"
    local violations=0
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    # Get file extension
    local ext="${file##*.}"
    
    # Skip non-code files
    case "$ext" in
        md|txt|json|yml|yaml|xml|html|css|lock|map|d.ts)
            log "Skipping non-code file: $file"
            return 0
            ;;
    esac
    
    echo "Checking: $file"
    
    # File length check
    local lines=$(wc -l < "$file")
    if [[ $lines -gt $MAX_FILE_LINES ]]; then
        echo "File length violation: $lines lines (max: $MAX_FILE_LINES)"
        ((violations++))
    fi
    
    # Line length check
    local long_lines=$(awk -v max="$MAX_LINE_LENGTH" 'length > max {print NR}' "$file" | head -5)
    if [[ -n "$long_lines" ]]; then
        echo "Line length violations on lines: $(echo $long_lines | tr '\n' ' ')"
        ((violations++))
    fi
    
    # Language-specific checks
    case "$ext" in
        ts|tsx|js|jsx)
            # JavaScript/TypeScript checks
            check_javascript "$file"
            violations=$((violations + $?))
            ;;
        py)
            # Python checks
            check_python "$file"
            violations=$((violations + $?))
            ;;
        rb)
            # Ruby checks
            check_ruby "$file"
            violations=$((violations + $?))
            ;;
    esac
    
    return $violations
}

# JavaScript/TypeScript specific checks
check_javascript() {
    local file="$1"
    local violations=0
    
    # Function length (simplified - counts from function to closing brace)
    local long_functions=$(awk -v max="$MAX_FUNCTION_LINES" '
        /function.*{|=>.*{/ { start=NR; brace=1 }
        start && /{/ { brace++ }
        start && /}/ { 
            brace--; 
            if (brace==0) { 
                len=NR-start+1; 
                if (len > max) print "Line " start ": function is " len " lines"
                start=0 
            }
        }
    ' "$file")
    
    if [[ -n "$long_functions" ]]; then
        echo "Function length violations:"
        echo "$long_functions"
        ((violations++))
    fi
    
    # Deep nesting (counts leading spaces/tabs)
    local deep_nesting=$(awk -v max="$MAX_NESTING" '
        /^[ \t]+[^ \t]/ {
            indent = gsub(/^[ \t]/, "", $0)
            depth = int(indent / 2)
            if (depth > max) print "Line " NR ": nesting depth " depth
        }
    ' "$file" | head -5)
    
    if [[ -n "$deep_nesting" ]]; then
        echo "Nesting depth violations:"
        echo "$deep_nesting"
        ((violations++))
    fi
    
    return $violations
}

# Python specific checks
check_python() {
    local file="$1"
    local violations=0
    
    # PEP8: 4-space indentation
    local bad_indent=$(grep -n '^[ ]\{1,3\}[^ ]' "$file" | grep -v '^ *#' | head -5)
    if [[ -n "$bad_indent" ]]; then
        echo "Python indentation violations (should be 4 spaces):"
        echo "$bad_indent"
        ((violations++))
    fi
    
    # Function length
    local long_functions=$(awk -v max="$MAX_FUNCTION_LINES" '
        /^def |^class / { start=NR; name=$2 }
        start && /^[^ ]/ && NR > start { 
            len=NR-start;
            if (len > max) print "Line " start ": " name " is " len " lines"
            start=0
        }
    ' "$file")
    
    if [[ -n "$long_functions" ]]; then
        echo "Function/class length violations:"
        echo "$long_functions"
        ((violations++))
    fi
    
    return $violations
}

# Ruby specific checks
check_ruby() {
    local file="$1"
    local violations=0
    
    # Ruby style: 2-space indentation
    local bad_indent=$(grep -n '^[ ]\{3,\}[^ ]' "$file" | grep -v '^ *#' | head -5)
    if [[ -n "$bad_indent" ]]; then
        echo "Ruby indentation violations (should be 2 spaces):"
        echo "$bad_indent"
        ((violations++))
    fi
    
    # Method length
    local long_methods=$(awk -v max="$MAX_FUNCTION_LINES" '
        /^[ ]*def / { start=NR; name=$2 }
        start && /^[ ]*end/ && NR > start { 
            len=NR-start+1;
            if (len > max) print "Line " start ": " name " is " len " lines"
            start=0
        }
    ' "$file")
    
    if [[ -n "$long_methods" ]]; then
        echo "Method length violations:"
        echo "$long_methods"
        ((violations++))
    fi
    
    return $violations
}

# Handle Stop events
if [[ "$EVENT_TYPE" == "Stop" ]]; then
    log "Processing Stop event"
    
    # Find recently modified files (all languages)
    RECENT_FILES=$(find . \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
                           -o -name "*.py" -o -name "*.rb" -o -name "*.go" -o -name "*.java" \) \
                   -mtime -10m 2>/dev/null | grep -v node_modules | grep -v "\.d\.ts$" | grep -v "^./lib/" | head -20)
    
    TOTAL_VIOLATIONS=0
    for file in $RECENT_FILES; do
        if [[ -f "$file" ]]; then
            check_file "$file"
            VIOLATIONS_FOUND=$?
            TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + VIOLATIONS_FOUND))
        fi
    done
    
    if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
        log "All checks passed"
        echo '{"continue": true}'
    else
        log "BLOCKING! Violations: $TOTAL_VIOLATIONS"
        cat <<EOF
{
  "continue": false,
  "stopReason": "Code quality violations in recent files",
  "decision": "block",
  "reason": "Found $TOTAL_VIOLATIONS code quality violations.\n\nPlease fix violations before proceeding."
}
EOF
    fi
    exit 0
fi

# Handle PostToolUse events
if [[ "$EVENT_TYPE" == "PostToolUse" ]] && [[ "$TOOL" =~ ^(Write|Edit|MultiEdit)$ ]] && [[ -n "$FILE_PATH" ]]; then
    log "Processing PostToolUse for $FILE_PATH"
    
    check_file "$FILE_PATH"
    VIOLATIONS=$?
    
    if [[ $VIOLATIONS -eq 0 ]]; then
        log "All checks passed for $FILE_PATH"
        echo '{"continue": true}'
    else
        log "BLOCKING! Violations in $FILE_PATH: $VIOLATIONS"
        cat <<EOF
{
  "continue": false,
  "stopReason": "Code quality violations",
  "decision": "block",
  "reason": "Found $VIOLATIONS code quality violations.\n\nPlease fix before proceeding."
}
EOF
    fi
    exit 0
fi

# Default: allow
echo '{"continue": true}'