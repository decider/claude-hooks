#!/bin/bash

# Build Code Index - Creates searchable index of codebase functions and utilities
# Run this periodically to keep the index up to date

set -euo pipefail

# Configuration
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
# Use project-relative path if running from project, otherwise use home directory
if [ -d "$(pwd)/claude/hooks" ]; then
    INDEX_FILE="${CLAUDE_CODE_INDEX:-$(pwd)/claude/hooks/code-index.json}"
else
    INDEX_FILE="${CLAUDE_CODE_INDEX:-$HOME/claude/hooks/code-index.json}"
fi
TEMP_FILE="/tmp/code-index-$$.json"

echo "🔍 Building code index for: $PROJECT_ROOT"

# Initialize JSON structure
cat > "$TEMP_FILE" << EOF
{
  "generated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "project": "$PROJECT_ROOT",
  "functions": [],
  "utilities": {},
  "components": [],
  "hooks": [],
  "types": []
}
EOF

# Function to extract TypeScript/JavaScript functions
index_ts_functions() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    
    # Skip node_modules and build directories
    if [[ "$file" =~ (node_modules|dist|build|\.next|coverage) ]]; then
        return
    fi
    
    # Extract exported functions and their descriptions
    grep -n "export\s\+\(function\|const\|async\s\+function\)" "$file" 2>/dev/null | while IFS=: read -r line_num line_content; do
        # Extract function name
        local func_name=$(echo "$line_content" | sed -E 's/export\s+(async\s+)?function\s+([a-zA-Z0-9_]+).*/\2/' | \
                         sed -E 's/export\s+const\s+([a-zA-Z0-9_]+).*/\1/')
        
        if [ -n "$func_name" ] && [[ "$func_name" =~ ^[a-zA-Z_] ]]; then
            # Try to get JSDoc comment above the function
            local doc_comment=""
            if [ "$line_num" -gt 1 ]; then
                local prev_line=$((line_num - 1))
                doc_comment=$(sed -n "${prev_line}p" "$file" | grep -oE '@description\s+.*' | sed 's/@description\s*//' || true)
            fi
            
            # Add to functions array
            jq --arg name "$func_name" \
               --arg file "$relative_path" \
               --arg line "$line_num" \
               --arg desc "$doc_comment" \
               '.functions += [{"name": $name, "file": $file, "line": ($line | tonumber), "description": $desc}]' \
               "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"
        fi
    done
}

# Function to index React components
index_react_components() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    
    # Skip non-component files
    if [[ ! "$file" =~ \.(tsx|jsx)$ ]] || [[ "$file" =~ (test|spec|stories) ]]; then
        return
    fi
    
    # Look for component exports
    grep -n "export\s\+\(default\s\+\)?function\s\+[A-Z]" "$file" 2>/dev/null | while IFS=: read -r line_num line_content; do
        local comp_name=$(echo "$line_content" | sed -E 's/.*function\s+([A-Z][a-zA-Z0-9_]*).*/\1/')
        
        if [ -n "$comp_name" ]; then
            jq --arg name "$comp_name" \
               --arg file "$relative_path" \
               --arg line "$line_num" \
               '.components += [{"name": $name, "file": $file, "line": ($line | tonumber)}]' \
               "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"
        fi
    done
}

# Function to index custom hooks
index_hooks() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    
    # Look for use* functions
    grep -n "export\s\+\(function\|const\)\s\+use[A-Z]" "$file" 2>/dev/null | while IFS=: read -r line_num line_content; do
        local hook_name=$(echo "$line_content" | sed -E 's/.*\s(use[A-Za-z0-9_]+).*/\1/')
        
        if [ -n "$hook_name" ]; then
            jq --arg name "$hook_name" \
               --arg file "$relative_path" \
               --arg line "$line_num" \
               '.hooks += [{"name": $name, "file": $file, "line": ($line | tonumber)}]' \
               "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"
        fi
    done
}

# Function to index TypeScript types and interfaces
index_types() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    
    # Look for exported types and interfaces
    grep -n "export\s\+\(type\|interface\)\s\+[A-Z]" "$file" 2>/dev/null | while IFS=: read -r line_num line_content; do
        local type_name=$(echo "$line_content" | sed -E 's/export\s+(type|interface)\s+([A-Za-z0-9_]+).*/\2/')
        
        if [ -n "$type_name" ]; then
            jq --arg name "$type_name" \
               --arg file "$relative_path" \
               --arg line "$line_num" \
               '.types += [{"name": $name, "file": $file, "line": ($line | tonumber)}]' \
               "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"
        fi
    done
}

# Function to identify common utility locations
index_utility_directories() {
    local utils_dirs=("utils" "helpers" "lib" "common" "shared")
    
    for dir in "${utils_dirs[@]}"; do
        find "$PROJECT_ROOT" -type d -name "$dir" 2>/dev/null | grep -v node_modules | while read -r util_dir; do
            local relative_dir="${util_dir#$PROJECT_ROOT/}"
            
            # Count utility files
            local util_count=$(find "$util_dir" -name "*.ts" -o -name "*.js" 2>/dev/null | grep -v test | wc -l)
            
            if [ "$util_count" -gt 0 ]; then
                jq --arg dir "$relative_dir" \
                   --arg count "$util_count" \
                   '.utilities[$dir] = ($count | tonumber)' \
                   "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"
            fi
        done
    done
}

# Main indexing process
echo "📂 Scanning TypeScript/JavaScript files..."

# Find all TS/JS files
echo "  Finding files..."
files=()
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find "$PROJECT_ROOT" \
    -type f \
    \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/target/*" \
    -print0 2>/dev/null)

total_files=${#files[@]}
echo "  Found $total_files files to index"

# Process files
file_count=0
for file in "${files[@]}"; do
    ((file_count++))
    echo -ne "\r  Processing: $file_count/$total_files files"
    
    index_ts_functions "$file"
    index_react_components "$file"
    index_hooks "$file"
    index_types "$file"
done

echo -e "\n📁 Indexing utility directories..."
index_utility_directories

# Add statistics
total_functions=$(jq '.functions | length' "$TEMP_FILE")
total_components=$(jq '.components | length' "$TEMP_FILE")
total_hooks=$(jq '.hooks | length' "$TEMP_FILE")
total_types=$(jq '.types | length' "$TEMP_FILE")

jq --arg funcs "$total_functions" \
   --arg comps "$total_components" \
   --arg hooks "$total_hooks" \
   --arg types "$total_types" \
   '.statistics = {
      "totalFunctions": ($funcs | tonumber),
      "totalComponents": ($comps | tonumber),
      "totalHooks": ($hooks | tonumber),
      "totalTypes": ($types | tonumber)
    }' \
   "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"

# Move to final location
mv "$TEMP_FILE" "$INDEX_FILE"

echo -e "\n✅ Code index built successfully!"
echo "📊 Statistics:"
echo "  - Functions: $total_functions"
echo "  - Components: $total_components"
echo "  - Hooks: $total_hooks"
echo "  - Types: $total_types"
echo "📍 Index saved to: $INDEX_FILE"

# Create a quick lookup script
cat > "$HOME/claude/hooks/lookup-function.sh" << 'EOF'
#!/bin/bash
# Quick function lookup script
QUERY="$1"
INDEX_FILE="${CLAUDE_CODE_INDEX:-$HOME/claude/hooks/code-index.json}"

if [ -z "$QUERY" ]; then
    echo "Usage: $0 <function-name>"
    exit 1
fi

jq -r --arg q "$QUERY" '
    .functions[] | 
    select(.name | test($q; "i")) | 
    "\(.name) - \(.file):\(.line)"
' "$INDEX_FILE" 2>/dev/null || echo "No matches found"
EOF

chmod +x "$HOME/claude/hooks/lookup-function.sh"
echo "💡 Tip: Use 'lookup-function <name>' to quickly find functions"