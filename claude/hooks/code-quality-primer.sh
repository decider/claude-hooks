#!/bin/bash


# Source logging library
HOOK_NAME="code-quality-primer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Log hook start
log_hook_start "$HOOK_NAME" "Hook invoked"

# Claude Code Pre-Hook: Code Quality & Reuse Primer
# Injects Clean Code principles and checks for existing code before creation

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty')

# Configuration
# Use project-relative paths if running from project
if [ -d "$(pwd)/claude/hooks" ]; then
    RULES_FILE="${CLAUDE_RULES_FILE:-$(pwd)/claude/hooks/clean-code-rules.json}"
    INDEX_FILE="${CLAUDE_CODE_INDEX:-$(pwd)/claude/hooks/code-index.json}"
else
    RULES_FILE="${CLAUDE_RULES_FILE:-$HOME/claude/hooks/clean-code-rules.json}"
    INDEX_FILE="${CLAUDE_CODE_INDEX:-$HOME/claude/hooks/code-index.json}"
fi

# Function to inject Clean Code reminders
inject_principles() {
    local file_type="$1"
    local principles=""
    
    case "$file_type" in
        "ts"|"tsx"|"js"|"jsx")
            principles="TypeScript/React Clean Code Reminders:
- Functions should do ONE thing (max 20 lines)
- Use descriptive names (searchUsers not getU)
- Avoid magic numbers - use named constants
- Prefer composition over inheritance
- Check for existing utilities before creating new ones"
            ;;
        "rs")
            principles="Rust Clean Code Reminders:
- Keep functions under 20 lines
- Use Result<T, E> for error handling
- Avoid unwrap() in production code
- Check existing modules for similar functionality"
            ;;
        *)
            principles="Clean Code Reminders:
- Single Responsibility Principle
- DRY - Don't Repeat Yourself
- Check for existing code first"
            ;;
    esac
    
    echo "$principles" >&2
}

# Function to check for similar existing code
check_existing_code() {
    local content="$1"
    local file_type="$2"
    
    # Extract function/component names from content
    local function_names=""
    case "$file_type" in
        "ts"|"tsx"|"js"|"jsx")
            # Extract function and const declarations
            function_names=$(echo "$content" | grep -E "(function\s+\w+|const\s+\w+\s*=|export\s+(function|const)\s+\w+)" | sed -E 's/.*(function|const)\s+(\w+).*/\2/' | sort -u)
            ;;
        "rs")
            # Extract Rust function declarations
            function_names=$(echo "$content" | grep -E "fn\s+\w+" | sed -E 's/.*fn\s+(\w+).*/\1/' | sort -u)
            ;;
    esac
    
    # Check each function against known patterns
    if [ -n "$function_names" ] && [ -f "$INDEX_FILE" ]; then
        while read -r func_name; do
            # Check for common utility patterns
            case "$func_name" in
                *format*Date*|*date*Format*)
                    echo "⚠️  WARNING: Date formatting function detected!" >&2
                    echo "   Consider using existing utilities:" >&2
                    echo "   - import { formatDate } from '@/utils/dateHelpers'" >&2
                    echo "   - import { format } from 'date-fns'" >&2
                    ;;
                *debounce*|*throttle*)
                    echo "⚠️  WARNING: Rate limiting function detected!" >&2
                    echo "   Consider using:" >&2
                    echo "   - import { debounce, throttle } from 'lodash-es'" >&2
                    ;;
                *deep*Clone*|*deep*Copy*)
                    echo "⚠️  WARNING: Deep cloning function detected!" >&2
                    echo "   Consider using:" >&2
                    echo "   - import { cloneDeep } from 'lodash-es'" >&2
                    ;;
                *camelCase*|*snakeCase*|*kebabCase*)
                    echo "⚠️  WARNING: Case conversion function detected!" >&2
                    echo "   Check existing converters in '@/api/converters.ts'" >&2
                    ;;
            esac
            
            # Search for similar function names in index
            if [ -f "$INDEX_FILE" ]; then
                similar=$(jq -r --arg name "$func_name" '.functions[] | select(.name | test($name; "i")) | "\(.name) in \(.file)"' "$INDEX_FILE" 2>/dev/null | head -5)
                if [ -n "$similar" ]; then
                    echo "📋 Similar existing functions found:" >&2
                    echo "$similar" | sed 's/^/   - /' >&2
                fi
            fi
        done <<< "$function_names"
    fi
}

# Main logic
if [[ "$TOOL" =~ ^(Write|Edit|MultiEdit)$ ]] && [ -n "$FILE_PATH" ]; then
    # Extract file extension
    file_ext="${FILE_PATH##*.}"
    
    # Only process code files
    if [[ "$file_ext" =~ ^(ts|tsx|js|jsx|rs|py)$ ]]; then
        echo "🔍 Code Quality Pre-Check for $FILE_PATH" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        
        # Inject principles
        inject_principles "$file_ext"
        echo "" >&2
        
        # Check for existing similar code
        if [ -n "$CONTENT" ]; then
            check_existing_code "$CONTENT" "$file_ext"
        fi
        
        # Add DRY reminder
        echo "" >&2
        echo "🔄 DRY Principle: Always check if similar code exists before creating new functions!" >&2
        echo "   Use existing utilities from:" >&2
        echo "   - Project utils (@/utils, @/helpers)" >&2
        echo "   - Standard libraries (lodash-es, date-fns)" >&2
        echo "   - Framework utilities (React hooks, Anchor helpers)" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    fi
fi

# Pass through the input
echo "$INPUT"

# Log hook completion
log_performance "$HOOK_NAME" $START_TIME
log_hook_end "$HOOK_NAME" 0

exit 0

