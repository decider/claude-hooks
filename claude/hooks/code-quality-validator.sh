#!/bin/bash


# Source logging library
HOOK_NAME="code-quality-validator"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Log hook start
log_hook_start "$HOOK_NAME" "Hook invoked"

# Claude Code Post-Hook: Code Quality Validator
# Validates code against Clean Code principles after operations

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // 0')

# Configuration
# Use project-relative paths if running from project
if [ -d "$(pwd)/claude/hooks" ]; then
    RULES_FILE="${CLAUDE_RULES_FILE:-$(pwd)/claude/hooks/clean-code-rules.json}"
else
    RULES_FILE="${CLAUDE_RULES_FILE:-$HOME/claude/hooks/clean-code-rules.json}"
fi

if [ ! -f "$RULES_FILE" ]; then
    # Use default rules if config doesn't exist
    MAX_FUNCTION_LINES=20
    MAX_FILE_LINES=100
    MAX_NESTING=3
    MAX_PARAMS=3
    MAX_LINE_LENGTH=80
else
    # Load rules from config
    MAX_FUNCTION_LINES=$(jq -r '.rules.maxFunctionLines // 20' "$RULES_FILE")
    MAX_FILE_LINES=$(jq -r '.rules.maxFileLines // 100' "$RULES_FILE")
    MAX_NESTING=$(jq -r '.rules.maxNestingDepth // 3' "$RULES_FILE")
    MAX_PARAMS=$(jq -r '.rules.maxParameters // 3' "$RULES_FILE")
    MAX_LINE_LENGTH=$(jq -r '.rules.maxLineLength // 80' "$RULES_FILE")
fi

# Function to count lines in a function
count_function_lines() {
    local file="$1"
    local violations=()
    
    # TypeScript/JavaScript function detection
    if [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
        # Find function blocks and count lines
        awk '
        /function\s+\w+\s*\(|const\s+\w+\s*=.*=>|\w+\s*\([^)]*\)\s*{/ {
            func_name = $0
            gsub(/^[[:space:]]*/, "", func_name)
            gsub(/[[:space:]]*{.*/, "", func_name)
            brace_count = 1
            line_count = 0
            in_function = 1
            start_line = NR
        }
        in_function {
            line_count++
            if (/{/) brace_count += gsub(/{/, "{")
            if (/}/) brace_count -= gsub(/}/, "}")
            if (brace_count == 0) {
                if (line_count > '"$MAX_FUNCTION_LINES"') {
                    print start_line ":" func_name ":" line_count
                }
                in_function = 0
            }
        }
        ' "$file"
    fi
}

# Function to check nesting depth
check_nesting_depth() {
    local file="$1"
    local max_depth=0
    local current_depth=0
    
    while IFS= read -r line; do
        # Count opening braces
        local opens=$(echo "$line" | tr -cd '{' | wc -c)
        # Count closing braces
        local closes=$(echo "$line" | tr -cd '}' | wc -c)
        
        current_depth=$((current_depth + opens - closes))
        if [ "$current_depth" -gt "$max_depth" ]; then
            max_depth=$current_depth
        fi
    done < "$file"
    
    echo "$max_depth"
}

# Function to check for magic numbers
check_magic_numbers() {
    local file="$1"
    # Find numeric literals (excluding 0, 1, -1)
    grep -nE '\b[0-9]+\.?[0-9]*\b' "$file" | \
        grep -vE '\b[01]\b|\.env|config|const|let|var' | \
        grep -vE '(0x|#)[0-9a-fA-F]+' | \
        head -5
}

# Function to validate a single file
validate_file() {
    local file="$1"
    local violations=()
    local warnings=()
    
    if [ ! -f "$file" ]; then
        return 0
    fi
    
    echo "🔍 Validating: $(basename "$file")" >&2
    
    # Check file length
    local line_count=$(wc -l < "$file")
    if [ "$line_count" -gt "$MAX_FILE_LINES" ]; then
        violations+=("❌ File too long: $line_count lines (max: $MAX_FILE_LINES)")
    fi
    
    # Check function lengths
    local long_functions=$(count_function_lines "$file")
    if [ -n "$long_functions" ]; then
        while IFS=: read -r line_num func_name func_lines; do
            violations+=("❌ Function too long at line $line_num: $func_lines lines (max: $MAX_FUNCTION_LINES)")
        done <<< "$long_functions"
    fi
    
    # Check nesting depth
    local max_nesting=$(check_nesting_depth "$file")
    if [ "$max_nesting" -gt "$MAX_NESTING" ]; then
        violations+=("❌ Excessive nesting: depth $max_nesting (max: $MAX_NESTING)")
    fi
    
    # Check line length
    local long_lines=$(awk -v max="$MAX_LINE_LENGTH" 'length($0) > max { print NR }' "$file" | head -5)
    if [ -n "$long_lines" ]; then
        local count=$(echo "$long_lines" | wc -l)
        violations+=("❌ $count lines exceed $MAX_LINE_LENGTH characters (lines: $(echo $long_lines | tr '\n' ', '))")
    fi
    
    # Check for magic numbers
    local magic_numbers=$(check_magic_numbers "$file")
    if [ -n "$magic_numbers" ]; then
        warnings+=("⚠️  Magic numbers detected - consider using named constants")
    fi
    
    # Check for excessive comments (code should be self-documenting)
    local total_lines=$(grep -cv '^[[:space:]]*$' "$file" || echo 0)
    local comment_lines=$(grep -cE '^\s*(//|/\*|\*|#)' "$file" || echo 0)
    if [ "$total_lines" -gt 0 ]; then
        local comment_ratio=$(echo "scale=2; $comment_lines / $total_lines" | bc)
        if (( $(echo "$comment_ratio > 0.2" | bc -l) )); then
            warnings+=("⚠️  High comment ratio: ${comment_ratio} (code should be self-documenting)")
        fi
    fi
    
    # Check for code duplication patterns
    if [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
        # Check for repeated similar function calls
        local repeated_patterns=$(grep -oE '\b\w+\(' "$file" | sort | uniq -c | sort -rn | awk '$1 > 5 {print $2}' | head -3)
        if [ -n "$repeated_patterns" ]; then
            warnings+=("⚠️  Repeated patterns detected - consider extracting to utilities")
        fi
    fi
    
    # Output results
    if [ ${#violations[@]} -gt 0 ]; then
        echo "━━━ CLEAN CODE VIOLATIONS ━━━" >&2
        printf '%s\n' "${violations[@]}" >&2
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "━━━ WARNINGS ━━━" >&2
        printf '%s\n' "${warnings[@]}" >&2
    fi
    
    if [ ${#violations[@]} -eq 0 ] && [ ${#warnings[@]} -eq 0 ]; then
        echo "✅ All Clean Code checks passed!" >&2
    fi
    
    # Return number of violations
    return ${#violations[@]}
}

# Main logic - only validate on successful write/edit operations
if [ "$EXIT_CODE" -eq 0 ] && [[ "$TOOL" =~ ^(Write|Edit|MultiEdit)$ ]] && [ -n "$FILE_PATH" ]; then
    # Only validate code files
    if [[ "$FILE_PATH" =~ \.(ts|tsx|js|jsx|rs|py)$ ]]; then
        echo "" >&2
        echo "🧹 Clean Code Validation" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        
        validate_file "$FILE_PATH"
        validation_result=$?
        
        if [ $validation_result -gt 0 ]; then
            echo "" >&2
            echo "💡 Suggestions:" >&2
            echo "   - Extract large functions into smaller, focused functions" >&2
            echo "   - Reduce nesting by using early returns" >&2
            echo "   - Use descriptive names instead of comments" >&2
            echo "   - Extract magic numbers to named constants" >&2
            echo "   - Check for existing utilities before creating new ones" >&2
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    fi
fi

# Always pass through the input
echo "$INPUT"

# Log hook completion
log_performance "$HOOK_NAME" $START_TIME
log_hook_end "$HOOK_NAME" 0

exit 0

