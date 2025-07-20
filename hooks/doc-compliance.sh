#!/bin/bash

# Documentation Compliance Hook
# Checks code changes against project documentation standards using Gemini Flash

# Removed strict mode as it was causing issues with regex matching

# Read hook input from stdin first
HOOK_INPUT=$(cat)
EVENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'

# Configuration paths
# When running from npm package, look in the user's project
if [ -n "$HOOK_PROJECT_ROOT" ]; then
    CONFIG_FILE="$HOOK_PROJECT_ROOT/.claude/doc-rules/config.json"
else
    # Look in current directory first
    if [ -f "./.claude/doc-rules/config.json" ]; then
        CONFIG_FILE="./.claude/doc-rules/config.json"
    elif [ -f "$(pwd)/.claude/doc-rules/config.json" ]; then
        CONFIG_FILE="$(pwd)/.claude/doc-rules/config.json"
    else
        CONFIG_FILE="${HOOK_PROJECT_ROOT:-$(pwd)}/.claude/doc-rules/config.json"
    fi
fi

# Load API key from multiple sources
# 1. Check ~/.gemini/.env
if [ -f "$HOME/.gemini/.env" ]; then
    source "$HOME/.gemini/.env"
fi

# 2. Check project root .env
if [ -f ".env" ]; then
    source ".env"
fi

# 3. Use environment variable if set
GEMINI_API_KEY="${GEMINI_API_KEY:-}"

# Check for API key - but allow Stop events to continue for code quality check
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}Error: GEMINI_API_KEY not found${NC}"
    echo -e "${YELLOW}Please set your Gemini API key in one of these locations:${NC}"
    echo "  1. Environment variable: export GEMINI_API_KEY='your-key'"
    echo "  2. ~/.gemini/.env file: GEMINI_API_KEY=your-key"
    echo "  3. Project .env file: GEMINI_API_KEY=your-key"
    echo -e "${YELLOW}Skipping documentation compliance check${NC}"
    
    # For Stop events, continue to run code quality checks even without API key
    if [ "$EVENT_TYPE" != "Stop" ]; then
        exit 0
    fi
    SKIP_DOC_COMPLIANCE=true
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Warning: Documentation rules config not found at $CONFIG_FILE${NC}"
    echo "Skipping documentation compliance check"
    exit 0
fi

# Function to get git changes
get_changed_files() {
    # Get both staged and unstaged changes
    git diff --name-only HEAD 2>/dev/null || true
    git diff --cached --name-only 2>/dev/null || true
}

# Function to get file content with changes
get_file_changes() {
    local file="$1"
    echo "=== File: $file ==="
    echo ""
    # Show the diff to understand what changed
    git diff HEAD -- "$file" 2>/dev/null || git diff --cached -- "$file" 2>/dev/null || cat "$file"
}

# Function to find matching documentation for a file
find_matching_docs() {
    local file="$1"
    local docs=""
    
    # Read config file
    if [ ! -f "$CONFIG_FILE" ]; then
        return
    fi
    
    # Parse fileTypes from config using jq
    if command -v jq >/dev/null 2>&1; then
        # Use jq for proper JSON parsing
        local file_types=$(jq -r '.fileTypes | to_entries[] | "\(.key)|\(.value | join(" "))"' "$CONFIG_FILE" 2>/dev/null)
        while IFS='|' read -r pattern doc_list; do
            case "$file" in
                $pattern) docs="$docs $doc_list" ;;
            esac
        done <<< "$file_types"
        
        # Parse directories from config
        local directories=$(jq -r '.directories | to_entries[] | "\(.key)|\(.value | join(" "))"' "$CONFIG_FILE" 2>/dev/null)
        while IFS='|' read -r pattern doc_list; do
            case "$file" in
                ${pattern}*) docs="$docs $doc_list" ;;
            esac
        done <<< "$directories"
    else
        # Fallback to hardcoded if jq not available
        case "$file" in
            *.ts) docs="docs/typescript-standards.md" ;;
            *.js) docs="docs/javascript-standards.md" ;;
            *.tsx|*.jsx) docs="docs/react-standards.md" ;;
            *.py) docs="docs/python-standards.md" ;;
            *.sol) docs="docs/solana-standards.md docs/smart-contract-security.md" ;;
            *.move) docs="docs/move-standards.md" ;;
        esac
        
        case "$file" in
            src/contracts/*) docs="$docs docs/contract-patterns.md docs/security-checklist.md" ;;
            src/components/*) docs="$docs docs/component-guidelines.md" ;;
            tests/*) docs="$docs docs/testing-standards.md" ;;
        esac
    fi
    
    # Remove duplicates and empty entries
    echo "$docs" | tr ' ' '\n' | sort -u | grep -v '^$'
}

# Function to get threshold for file
get_threshold() {
    local file="$1"
    local threshold="0.8" # default
    
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        # First try to get default threshold
        threshold=$(jq -r '.thresholds.default // 0.8' "$CONFIG_FILE" 2>/dev/null)
        
        # Check for specific patterns in config
        local thresholds=$(jq -r '.thresholds | to_entries[] | select(.key != "default") | "\(.key)|\(.value)"' "$CONFIG_FILE" 2>/dev/null)
        while IFS='|' read -r pattern value; do
            case "$file" in
                $pattern) threshold="$value" ;;
            esac
        done <<< "$thresholds"
    else
        # Fallback to hardcoded
        case "$file" in
            *.sol|*.move) threshold="0.9" ;;
            src/contracts/*) threshold="0.95" ;;
        esac
    fi
    
    echo "$threshold"
}

# Function to read documentation content
read_documentation() {
    local doc_path="$1"
    local full_path="${HOOK_PROJECT_ROOT:-$(pwd)}/$doc_path"
    
    if [ -f "$full_path" ]; then
        echo "=== Documentation: $doc_path ==="
        echo ""
        cat "$full_path"
        echo ""
    else
        echo "Warning: Documentation file not found: $doc_path" >&2
    fi
}


# Function to compare floats
compare_floats() {
    local score="$1"
    local threshold="$2"
    
    # Convert to integers by multiplying by 100
    local score_int=$(awk "BEGIN {print int($score * 100)}")
    local threshold_int=$(awk "BEGIN {print int($threshold * 100)}")
    
    [ "$score_int" -lt "$threshold_int" ]
}

# ============================================================================
# CODE QUALITY EVALUATION FUNCTIONS
# ============================================================================

# Function to get code quality rules from config
get_code_quality_rules() {
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        MAX_FUNCTION_LINES=$(jq -r '.evaluations.codeQuality.rules.maxFunctionLines // 20' "$CONFIG_FILE")
        MAX_FILE_LINES=$(jq -r '.evaluations.codeQuality.rules.maxFileLines // 100' "$CONFIG_FILE")
        MAX_NESTING=$(jq -r '.evaluations.codeQuality.rules.maxNestingDepth // 3' "$CONFIG_FILE")
        MAX_PARAMS=$(jq -r '.evaluations.codeQuality.rules.maxParameters // 3' "$CONFIG_FILE")
        MAX_LINE_LENGTH=$(jq -r '.evaluations.codeQuality.rules.maxLineLength // 80' "$CONFIG_FILE")
    else
        # Default values
        MAX_FUNCTION_LINES=20
        MAX_FILE_LINES=100
        MAX_NESTING=3
        MAX_PARAMS=3
        MAX_LINE_LENGTH=80
    fi
}

# Function to check if code quality evaluation is enabled for a file
is_code_quality_enabled() {
    local file="$1"
    
    if [ ! -f "$CONFIG_FILE" ] || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if codeQuality evaluation is enabled
    local enabled=$(jq -r '.evaluations.codeQuality.enabled // false' "$CONFIG_FILE")
    if [ "$enabled" != "true" ]; then
        return 1
    fi
    
    # Check if file matches any of the specified file types
    local file_types=$(jq -r '.evaluations.codeQuality.fileTypes[]' "$CONFIG_FILE" 2>/dev/null)
    while IFS= read -r pattern; do
        case "$file" in
            $pattern) return 0 ;;
        esac
    done <<< "$file_types"
    
    return 1
}

# Function to count lines in a function
count_function_lines() {
    local file="$1"
    
    # TypeScript/JavaScript function detection
    if [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
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

# Function to get code quality threshold for file
get_code_quality_threshold() {
    local file="$1"
    local threshold="0.8" # default
    
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        # First try to get default threshold
        threshold=$(jq -r '.evaluations.codeQuality.thresholds.default // 0.8' "$CONFIG_FILE" 2>/dev/null)
        
        # Check for specific patterns in config
        local thresholds=$(jq -r '.evaluations.codeQuality.thresholds | to_entries[] | select(.key != "default") | "\(.key)|\(.value)"' "$CONFIG_FILE" 2>/dev/null)
        while IFS='|' read -r pattern value; do
            case "$file" in
                $pattern) threshold="$value" ;;
            esac
        done <<< "$thresholds"
    fi
    
    echo "$threshold"
}

# Function to evaluate code quality for a single file
evaluate_file_code_quality() {
    local file="$1"
    local violations=()
    local warnings=()
    local score=1.0
    local total_checks=0
    local failed_checks=0
    
    if [ ! -f "$file" ]; then
        echo "1.0|||" # score|issues|suggestions
        return 0
    fi
    
    # Get code quality rules
    get_code_quality_rules
    
    # Check file length
    local line_count=$(wc -l < "$file")
    total_checks=$((total_checks + 1))
    if [ "$line_count" -gt "$MAX_FILE_LINES" ]; then
        violations+=("$file:1:fileLength(): file too long ($line_count lines, max: $MAX_FILE_LINES)")
        failed_checks=$((failed_checks + 1))
    fi
    
    # Check function lengths
    local long_functions=$(count_function_lines "$file")
    if [ -n "$long_functions" ]; then
        while IFS=: read -r line_num func_name func_lines; do
            total_checks=$((total_checks + 1))
            violations+=("$file:$line_num:$func_name(): function too long ($func_lines lines, max: $MAX_FUNCTION_LINES)")
            failed_checks=$((failed_checks + 1))
        done <<< "$long_functions"
    fi
    
    # Check nesting depth
    local max_nesting=$(check_nesting_depth "$file")
    total_checks=$((total_checks + 1))
    if [ "$max_nesting" -gt "$MAX_NESTING" ]; then
        violations+=("$file:1:nestingDepth(): excessive nesting (depth $max_nesting, max: $MAX_NESTING)")
        failed_checks=$((failed_checks + 1))
    fi
    
    # Check line length
    local long_lines=$(awk -v max="$MAX_LINE_LENGTH" 'length($0) > max { print NR }' "$file" | head -5)
    if [ -n "$long_lines" ]; then
        local count=$(echo "$long_lines" | wc -l)
        total_checks=$((total_checks + 1))
        violations+=("$file:$(echo "$long_lines" | head -1):lineLength(): $count lines exceed $MAX_LINE_LENGTH characters")
        failed_checks=$((failed_checks + 1))
    fi
    
    # Check for magic numbers
    local magic_numbers=$(check_magic_numbers "$file")
    if [ -n "$magic_numbers" ]; then
        total_checks=$((total_checks + 1))
        warnings+=("$file:1:magicNumbers(): magic numbers detected - consider using named constants")
    fi
    
    # Calculate score
    if [ "$total_checks" -gt 0 ]; then
        score=$(echo "scale=2; 1 - ($failed_checks / $total_checks)" | bc)
    fi
    
    # Format issues and suggestions
    local issues=""
    local suggestions=""
    
    if [ ${#violations[@]} -gt 0 ]; then
        issues=$(printf '%s | ' "${violations[@]}")
        issues=${issues% | } # Remove trailing separator
        
        # Generate suggestions based on violations
        for violation in "${violations[@]}"; do
            if [[ "$violation" == *"function too long"* ]]; then
                suggestions="$suggestions$(echo "$violation" | cut -d: -f1-3): extract logic into smaller functions | "
            elif [[ "$violation" == *"excessive nesting"* ]]; then
                suggestions="$suggestions$(echo "$violation" | cut -d: -f1-3): use early returns to reduce nesting | "
            elif [[ "$violation" == *"file too long"* ]]; then
                suggestions="$suggestions$(echo "$violation" | cut -d: -f1-3): split into multiple focused modules | "
            elif [[ "$violation" == *"exceed"* ]]; then
                suggestions="$suggestions$(echo "$violation" | cut -d: -f1-3): break long lines for readability | "
            fi
        done
        suggestions=${suggestions% | } # Remove trailing separator
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        for warning in "${warnings[@]}"; do
            if [[ "$warning" == *"magic numbers"* ]]; then
                suggestions="$suggestions$(echo "$warning" | cut -d: -f1-3): create named constants for magic numbers | "
            fi
        done
        suggestions=${suggestions% | } # Remove trailing separator
    fi
    
    echo "$score|||$issues|||$suggestions"
}

# Function to run code quality evaluation on all applicable files
run_code_quality_evaluation() {
    local files_to_check="$1"
    local evaluation_output=""
    local overall_score=1.0
    local total_files=0
    local all_issues=""
    local all_suggestions=""
    
    echo -e "${GRAY}[DEBUG] run_code_quality_evaluation called with: '$files_to_check'${NC}" >&2
    
    # Check if code quality evaluation is enabled
    if [ ! -f "$CONFIG_FILE" ] || ! command -v jq >/dev/null 2>&1; then
        echo -e "${GRAY}[DEBUG] CONFIG_FILE missing or jq not available${NC}" >&2
        return 0
    fi
    
    local enabled=$(jq -r '.evaluations.codeQuality.enabled // false' "$CONFIG_FILE")
    echo -e "${GRAY}[DEBUG] Code quality enabled: $enabled${NC}" >&2
    if [ "$enabled" != "true" ]; then
        return 0
    fi
    
    # Use IFS approach instead of process substitution to preserve variable scope
    OLD_IFS="$IFS"
    IFS=$'\n'
    for file in $files_to_check; do
        echo -e "${GRAY}[DEBUG] Processing file: '$file'${NC}" >&2
        [ -f "$file" ] || { echo -e "${GRAY}[DEBUG] File not found: '$file'${NC}" >&2; continue; }
        
        if is_code_quality_enabled "$file"; then
            echo -e "${GRAY}[DEBUG] Code quality enabled for: '$file'${NC}" >&2
            total_files=$((total_files + 1))
            local result=$(evaluate_file_code_quality "$file")
            echo -e "${GRAY}[DEBUG] File '$file' result: '$result'${NC}" >&2
            local file_score=$(echo "$result" | cut -d'|' -f1)
            local file_issues=$(echo "$result" | sed 's/^[^|]*|||//; s/|||.*$//')
            local file_suggestions=$(echo "$result" | sed 's/^.*|||//')
            
            # Add to overall results
            if [ -n "$file_issues" ]; then
                all_issues="$all_issues$file_issues | "
            fi
            if [ -n "$file_suggestions" ]; then
                all_suggestions="$all_suggestions$file_suggestions | "
            fi
            
            # Update overall score (accumulate for averaging)
            overall_score=$(echo "scale=2; $overall_score + $file_score" | bc)
        else
            echo -e "${GRAY}[DEBUG] Code quality NOT enabled for: '$file'${NC}" >&2
        fi
    done
    IFS="$OLD_IFS"
    
    if [ "$total_files" -gt 0 ]; then
        overall_score=$(echo "scale=2; ($overall_score - 1.0) / $total_files" | bc)
        all_issues=${all_issues% | } # Remove trailing separator
        all_suggestions=${all_suggestions% | } # Remove trailing separator
        
        # Get threshold
        local threshold=$(jq -r '.evaluations.codeQuality.thresholds.default // 0.8' "$CONFIG_FILE")
        
        echo "$overall_score|||$threshold|||$all_issues|||$all_suggestions|||$total_files"
    fi
}

# ============================================================================
# EVALUATION RUNNER FUNCTIONS  
# ============================================================================

# Function to run all enabled evaluations and combine results
run_evaluations() {
    local files_to_check="$1"
    local evaluation_results=""
    local combined_score=1.0
    local total_evaluations=0
    local combined_issues=""
    local combined_suggestions=""
    
    if [ ! -f "$CONFIG_FILE" ] || ! command -v jq >/dev/null 2>&1; then
        echo "1.0|||0" # score|issues|suggestions|count
        return 0
    fi
    
    # Check if evaluations section exists
    local evaluations_exist=$(jq -r 'has("evaluations")' "$CONFIG_FILE" 2>/dev/null)
    if [ "$evaluations_exist" != "true" ]; then
        echo "1.0|||0"
        return 0
    fi
    
    # Run code quality evaluation if enabled
    local code_quality_result=$(run_code_quality_evaluation "$files_to_check")
    if [ -n "$code_quality_result" ]; then
        local cq_score=$(echo "$code_quality_result" | cut -d'|' -f1)
        local cq_threshold=$(echo "$code_quality_result" | sed -n 's/^[^|]*|||//; s/|||.*//p')
        local cq_issues=$(echo "$code_quality_result" | sed -n 's/^[^|]*|||[^|]*|||//; s/|||.*//p')
        local cq_suggestions=$(echo "$code_quality_result" | sed -n 's/^[^|]*|||[^|]*|||[^|]*|||//; s/|||.*//p')
        local cq_files=$(echo "$code_quality_result" | sed 's/^.*|||//')
        
        if [ -n "$cq_score" ] && [ "$cq_files" -gt 0 ]; then
            total_evaluations=$((total_evaluations + 1))
            combined_score=$(echo "scale=2; $combined_score + $cq_score" | bc)
            
            if [ -n "$cq_issues" ]; then
                combined_issues="$combined_issues$cq_issues | "
            fi
            if [ -n "$cq_suggestions" ]; then
                combined_suggestions="$combined_suggestions$cq_suggestions | "
            fi
        fi
    fi
    
    # Calculate final average score
    if [ "$total_evaluations" -gt 0 ]; then
        combined_score=$(echo "scale=2; ($combined_score - 1.0) / $total_evaluations" | bc)
        combined_issues=${combined_issues% | } # Remove trailing separator
        combined_suggestions=${combined_suggestions% | } # Remove trailing separator
    fi
    
    echo "$combined_score|$combined_issues|$combined_suggestions|$total_evaluations"
}

# Main execution
echo -e "${BOLD}Documentation Compliance Check${NC}"
echo "================================"

# Get changed files
changed_files=$(get_changed_files | sort -u)

if [ -z "$changed_files" ]; then
    echo "No changed files detected"
    
    # For Stop events, even with no changes, we should check if this is intentional
    if [ "$EVENT_TYPE" = "Stop" ]; then
        echo -e "\n${YELLOW}Stop event detected with no changes - allowing to proceed${NC}"
        exit 0
    fi
    
    exit 0
fi

# Collect all files with documentation rules and their content
all_files_content=""
all_docs_content=""
files_to_check=""
file_count=0

echo -e "\nAnalyzing files against documentation standards..."

# Process each changed file - collect ALL files for potential code quality checking
while IFS= read -r file; do
    # Skip if file doesn't exist (might be deleted)
    [ -f "$file" ] || continue
    
    # Add to files_to_check for code quality evaluation regardless of docs
    files_to_check="$files_to_check$file
"
    
    # Find matching documentation
    matching_docs=$(find_matching_docs "$file")
    
    if [ -z "$matching_docs" ]; then
        continue
    fi
    
    file_count=$((file_count + 1))
    
    # Get only the diff (changed lines)
    echo -e "  • $file"
    
    # Get only added/modified lines from diff
    file_content=$(git diff HEAD -- "$file" 2>/dev/null | grep -E "^[+]" | grep -v "^+++" | sed 's/^+//' | head -50)
    # If no diff, try staged
    if [ -z "$file_content" ]; then
        file_content=$(git diff --cached -- "$file" 2>/dev/null | grep -E "^[+]" | grep -v "^+++" | sed 's/^+//' | head -50)
    fi
    # If still nothing (new file), just get first 20 lines
    if [ -z "$file_content" ]; then
        file_content=$(head -20 "$file" 2>/dev/null || echo "File not readable")
    fi
    
    all_files_content="$all_files_content

=== FILE: $file ===
$file_content"
    
    # Collect relevant documentation (avoid duplicates)
    while IFS= read -r doc; do
        if [[ ! "$all_docs_content" == *"$doc"* ]]; then
            doc_content=$(read_documentation "$doc" 2>/dev/null)
            if [ -n "$doc_content" ]; then
                all_docs_content="$all_docs_content

$doc_content"
            fi
        fi
    done <<< "$matching_docs"
done <<< "$changed_files"

if [ $file_count -eq 0 ]; then
    echo -e "\n${YELLOW}No files found with documentation rules${NC}"
    exit 0
fi

# Get default threshold
if command -v jq >/dev/null 2>&1; then
    threshold=$(jq -r '.thresholds.default // 0.8' "$CONFIG_FILE" 2>/dev/null)
else
    threshold="0.8"
fi

echo -e "\nMaking compliance check (threshold: $threshold)..."
echo -e "${GRAY}Files to check: $file_count${NC}"

# Check if we have any documentation content or if API key is missing
if [ "$SKIP_DOC_COMPLIANCE" = "true" ] || [ -z "$all_docs_content" ] || [ "$all_docs_content" = $'\n\n' ]; then
    if [ "$SKIP_DOC_COMPLIANCE" = "true" ]; then
        echo -e "\n${YELLOW}Skipping documentation compliance due to missing GEMINI_API_KEY${NC}"
    else
        echo -e "\n${YELLOW}Warning: No documentation files found for the changed files${NC}"
        echo -e "${YELLOW}Cannot perform compliance check without documentation standards${NC}"
        echo -e "\nPlease create documentation files as specified in $CONFIG_FILE"
    fi
    
    # For Stop events, still run code quality checks even if docs are skipped
    if [ "$EVENT_TYPE" = "Stop" ]; then
        echo -e "\n${YELLOW}Running code quality evaluation for Stop event...${NC}"
        
        # Run code quality evaluation directly
        echo -e "${GRAY}Debug: files_to_check content:${NC}"
        echo "$files_to_check"
        echo -e "${GRAY}Running evaluation...${NC}"
        
        evaluation_result=$(run_evaluations "$files_to_check")
        echo -e "${GRAY}Debug: evaluation_result = '$evaluation_result'${NC}"
        
        eval_score=$(echo "$evaluation_result" | cut -d'|' -f1)
        eval_issues=$(echo "$evaluation_result" | cut -d'|' -f2)
        eval_suggestions=$(echo "$evaluation_result" | cut -d'|' -f3)
        eval_count=$(echo "$evaluation_result" | cut -d'|' -f4)
        
        echo -e "${GRAY}Debug: score=$eval_score, issues='$eval_issues', suggestions='$eval_suggestions', count=$eval_count${NC}"
        
        if [ -n "$eval_score" ]; then
            # Get threshold
            threshold=$(jq -r '.evaluations.codeQuality.thresholds.default // 0.8' "$CONFIG_FILE" 2>/dev/null || echo "0.8")
            
            if compare_floats "$eval_score" "$threshold"; then
                echo -e "\n${RED}❌ Code quality check failed! (Score: $eval_score/$threshold)${NC}"
                
                # Build reason message
                REASON="Code quality standards not met (score: $eval_score/$threshold).\\n\\nIssues to fix:\\n"
                echo "$eval_issues" | sed 's/ | /\\n/g' | while IFS= read -r issue; do
                    if [ -n "$issue" ]; then
                        REASON="$REASON• $issue\\n"
                    fi
                done
                
                cat <<EOF
{
  "continue": false,
  "stopReason": "Code quality standards not met (score: $eval_score/$threshold)",
  "decision": "block",
  "reason": "$REASON"
}
EOF
                exit 0
            else
                echo -e "\n${GREEN}✅ Code quality check passed!${NC}"
                exit 0
            fi
        fi
    fi
    
    exit 0
fi

# Make single API call with all context
prompt="Analyze the following code files for compliance with the provided documentation standards.

FILES TO ANALYZE:
$all_files_content

DOCUMENTATION STANDARDS:
$all_docs_content

Evaluate the overall compliance of ALL files against ALL applicable documentation standards.
Consider:
- How well the code follows the documented conventions
- Whether best practices are followed
- Code quality and maintainability
- Consistency across files

Respond with ONLY a JSON object in this exact format:
{
  \"score\": 0.73,
  \"summary\": \"Brief overall assessment\",
  \"issues\": \"filename.ts:123:functionName(): missing return type | filename.ts:45:variableName: uses 'any' type | another-file.js:200:methodName(): no error handling\",
  \"suggestions\": \"filename.ts:123: add ': Promise<User>' return type | filename.ts:45: replace 'any' with specific interface | another-file.js:200: wrap in try-catch block\"
}

Include line numbers and function/method names where possible.

The score should be between 0 and 1, where 1 means perfect compliance."

# Use Gemini Flash API

# Escape prompt for JSON
escaped_prompt=$(echo "$prompt" | jq -Rs .)

# Create the API request
api_response=$(curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
        \"contents\": [{
            \"parts\": [{
                \"text\": $escaped_prompt
            }]
        }],
        \"generationConfig\": {
            \"temperature\": 0.1,
            \"maxOutputTokens\": 500
        }
    }")

# Extract content from response (Gemini uses different JSON structure)
content=$(echo "$api_response" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null)

# Check if API call failed
if [ -z "$content" ]; then
    echo -e "\n${RED}Error: Failed to get Gemini response${NC}"
    echo "Response: $api_response"
    exit 2
fi


# Remove markdown code blocks if present
clean_content=$(echo "$content" | sed '/^```/d')

# Parse the response
score=$(echo "$clean_content" | grep -o '"score"[[:space:]]*:[[:space:]]*[0-9.]*' | sed 's/.*:[[:space:]]*//')
summary=$(echo "$clean_content" | grep -o '"summary"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')
issues=$(echo "$clean_content" | grep -o '"issues"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')
suggestions=$(echo "$clean_content" | grep -o '"suggestions"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')

# Default values
score=${score:-0}
summary=${summary:-"Analysis complete"}

# Display results
echo -e "\n${BOLD}Overall Compliance Score: $score${NC} (threshold: $threshold)"
echo -e "\n$summary"

# Check if passed
if compare_floats "$score" "$threshold"; then
    echo -e "\n${RED}❌ Documentation compliance check failed!${NC}"
    echo -e "\n${BOLD}Issues:${NC}"
    # Process and group issues by file
    current_file=""
    echo "$issues" | sed 's/ | /\n/g' | sort | while IFS= read -r issue; do
        if [ -n "$issue" ]; then
            # Extract file:line:method: issue pattern
            if [[ "$issue" =~ ^([^:]+):([0-9]+):([^:]+):(.*)$ ]]; then
                file="${BASH_REMATCH[1]}"
                line="${BASH_REMATCH[2]}"
                method="${BASH_REMATCH[3]}"
                desc="${BASH_REMATCH[4]}"
                
                # Print file header if it's a new file
                if [ "$file" != "$current_file" ]; then
                    if [ -n "$current_file" ]; then
                        echo "-----"
                    fi
                    echo -e "\n${YELLOW}$file${NC}"
                    current_file="$file"
                fi
                
                echo -e "  ${CYAN}$line${NC}: ${BOLD}$method${NC}${desc}"
            else
                echo -e "  $issue"
            fi
        fi
    done
    if [ -n "$current_file" ]; then
        echo "-----"
    fi
    echo -e "\n${BOLD}Fixes:${NC}"
    # Process and group fixes by file
    current_file=""
    echo "$suggestions" | sed 's/ | /\n/g' | sort | while IFS= read -r suggestion; do
        if [ -n "$suggestion" ]; then
            # Extract file:line: suggestion pattern
            if [[ "$suggestion" =~ ^([^:]+):([0-9]+):(.*)$ ]]; then
                file="${BASH_REMATCH[1]}"
                line="${BASH_REMATCH[2]}"
                fix="${BASH_REMATCH[3]}"
                
                # Print file header if it's a new file
                if [ "$file" != "$current_file" ]; then
                    if [ -n "$current_file" ]; then
                        echo "-----"
                    fi
                    echo -e "\n${YELLOW}$file${NC}"
                    current_file="$file"
                fi
                
                echo -e "  ${CYAN}$line${NC}: →${fix}"
            else
                echo -e "  $suggestion"
            fi
        fi
    done
    if [ -n "$current_file" ]; then
        echo "-----"
    fi
    
    # Build reason message for Claude with formatted issues and fixes
    REASON="Documentation compliance failed (score: $score, required: $threshold).\n\n$summary\n\nIssues to fix:\n"
    
    # Add issues
    echo "$issues" | sed 's/ | /\n/g' | while IFS= read -r issue; do
        if [ -n "$issue" ]; then
            REASON="$REASON• $issue\n"
        fi
    done
    
    REASON="$REASON\nSuggested fixes:\n"
    
    # Add suggestions
    echo "$suggestions" | sed 's/ | /\n/g' | while IFS= read -r suggestion; do
        if [ -n "$suggestion" ]; then
            REASON="$REASON• $suggestion\n"
        fi
    done
    
    # For Stop events, check if this is a Stop hook
    if [ "$EVENT_TYPE" = "Stop" ]; then
        # This is a Stop event - run additional evaluations and combine results
        echo -e "\n${YELLOW}Running additional quality evaluations...${NC}"
        
        # Run all evaluations (including code quality)
        evaluation_result=$(run_evaluations "$files_to_check")
        eval_score=$(echo "$evaluation_result" | cut -d'|' -f1)
        eval_issues=$(echo "$evaluation_result" | cut -d'|' -f2)
        eval_suggestions=$(echo "$evaluation_result" | cut -d'|' -f3)
        eval_count=$(echo "$evaluation_result" | cut -d'|' -f4)
        
        # Combine documentation and evaluation results
        if [ "$eval_count" -gt 0 ]; then
            # Calculate combined score (average of doc compliance and evaluations)
            combined_score=$(echo "scale=2; ($score + $eval_score) / 2" | bc)
            
            # Combine issues and suggestions
            all_issues="$issues"
            if [ -n "$eval_issues" ]; then
                if [ -n "$all_issues" ]; then
                    all_issues="$all_issues | $eval_issues"
                else
                    all_issues="$eval_issues"
                fi
            fi
            
            all_suggestions="$suggestions"
            if [ -n "$eval_suggestions" ]; then
                if [ -n "$all_suggestions" ]; then
                    all_suggestions="$all_suggestions | $eval_suggestions"
                else
                    all_suggestions="$eval_suggestions"
                fi
            fi
            
            # Update reason with combined results
            REASON="Quality standards not met (documentation: $score/$threshold, overall: $combined_score).\\n\\n$summary\\n\\nAll issues to fix:\\n"
            
            # Add combined issues
            echo "$all_issues" | sed 's/ | /\\n/g' | while IFS= read -r issue; do
                if [ -n "$issue" ]; then
                    REASON="$REASON• $issue\\n"
                fi
            done
            
            REASON="$REASON\\nSuggested fixes:\\n"
            
            # Add combined suggestions
            echo "$all_suggestions" | sed 's/ | /\\n/g' | while IFS= read -r suggestion; do
                if [ -n "$suggestion" ]; then
                    REASON="$REASON• $suggestion\\n"
                fi
            done
            
            # Use the lower score for the final decision
            final_score=$(echo "scale=2; if ($score < $eval_score) $score else $eval_score" | bc)
            if compare_floats "$final_score" "$threshold"; then
                echo -e "\n${RED}❌ Quality gate failed! (Score: $final_score/$threshold)${NC}"
                
                cat <<EOF
{
  "continue": false,
  "stopReason": "Quality standards not met (score: $final_score/$threshold)",
  "decision": "block",
  "reason": "$REASON"
}
EOF
                exit 0
            else
                echo -e "\n${GREEN}✅ All quality checks passed!${NC}"
                exit 0
            fi
        else
            # No additional evaluations, use original logic
            cat <<EOF
{
  "continue": false,
  "stopReason": "Documentation standards not met (score: $score/$threshold)",
  "decision": "block",
  "reason": "$REASON"
}
EOF
            exit 0  # Use exit 0 when outputting JSON
        fi
    else
        # For other events, just exit with error code
        exit 2
    fi
else
    echo -e "\n${GREEN}✅ All files passed documentation compliance check!${NC}"
    exit 0
fi