#!/bin/bash

# Documentation Compliance Hook
# Checks code changes against project documentation standards using Claude

# Removed strict mode as it was causing issues with regex matching

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

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

# Check for API key
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}Error: GEMINI_API_KEY not found${NC}"
    echo -e "${YELLOW}Please set your Gemini API key in one of these locations:${NC}"
    echo "  1. Environment variable: export GEMINI_API_KEY='your-key'"
    echo "  2. ~/.gemini/.env file: GEMINI_API_KEY=your-key"
    echo "  3. Project .env file: GEMINI_API_KEY=your-key"
    echo -e "${YELLOW}Skipping documentation compliance check${NC}"
    exit 0
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

# Main execution
echo -e "${BOLD}Documentation Compliance Check${NC}"
echo "================================"

# Get changed files
changed_files=$(get_changed_files | sort -u)

if [ -z "$changed_files" ]; then
    echo "No changed files detected"
    exit 0
fi

# Collect all files with documentation rules and their content
all_files_content=""
all_docs_content=""
files_to_check=""
file_count=0

echo -e "\nAnalyzing files against documentation standards..."

# Process each changed file
while IFS= read -r file; do
    # Skip if file doesn't exist (might be deleted)
    [ -f "$file" ] || continue
    
    # Find matching documentation
    matching_docs=$(find_matching_docs "$file")
    
    if [ -z "$matching_docs" ]; then
        continue
    fi
    
    file_count=$((file_count + 1))
    files_to_check="$files_to_check$file\n"
    
    # Get only the diff (changed lines)
    echo -e "  • $file"
    echo "DEBUG: Getting diff..."
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
    echo "DEBUG: Got ${#file_content} characters"
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

# Check if we have any documentation content
if [ -z "$all_docs_content" ] || [ "$all_docs_content" = $'\n\n' ]; then
    echo -e "\n${YELLOW}Warning: No documentation files found for the changed files${NC}"
    echo -e "${YELLOW}Cannot perform compliance check without documentation standards${NC}"
    echo -e "\nPlease create documentation files as specified in $CONFIG_FILE"
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
echo "DEBUG: Calling Gemini Flash API..."

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
    exit 2
else
    echo -e "\n${GREEN}✅ All files passed documentation compliance check!${NC}"
    exit 0
fi