#!/bin/bash

# Quick indexer - faster but less detailed
echo "🚀 Running quick code index..."

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
# Use project-relative path if running from project, otherwise use home directory
if [ -d "$(pwd)/claude/hooks" ]; then
    INDEX_FILE="${CLAUDE_CODE_INDEX:-$(pwd)/claude/hooks/code-index.json}"
else
    INDEX_FILE="${CLAUDE_CODE_INDEX:-$HOME/claude/hooks/code-index.json}"
fi

# Create basic index structure
cat > "$INDEX_FILE" << EOF
{
  "generated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "project": "$PROJECT_ROOT",
  "functions": [],
  "utilities": {
    "src/utils": $(find "$PROJECT_ROOT/apps/web/src/utils" -name "*.ts" 2>/dev/null | wc -l),
    "src/helpers": $(find "$PROJECT_ROOT/apps/web/src/helpers" -name "*.ts" 2>/dev/null | wc -l),
    "src/api": $(find "$PROJECT_ROOT/apps/web/src/api" -name "*.ts" 2>/dev/null | wc -l)
  },
  "quickStats": {
    "totalTypeScriptFiles": $(find "$PROJECT_ROOT" -name "*.ts" -o -name "*.tsx" | grep -v node_modules | wc -l),
    "webAppFiles": $(find "$PROJECT_ROOT/apps/web" -name "*.ts" -o -name "*.tsx" | wc -l),
    "apiFiles": $(find "$PROJECT_ROOT/apps/api" -name "*.ts" | wc -l),
    "solanaFiles": $(find "$PROJECT_ROOT/apps/solana" -name "*.ts" -o -name "*.rs" | wc -l)
  }
}
EOF

echo "✅ Quick index created at: $INDEX_FILE"

# Create a simplified function list
echo "📋 Creating function list..."
grep -r "export.*function\|export.*const.*=" "$PROJECT_ROOT/apps/web/src" --include="*.ts" --include="*.tsx" 2>/dev/null | \
    grep -v node_modules | \
    sed 's/:export.*function /: /' | \
    sed 's/:export.*const /: /' | \
    sed 's/ =.*//' | \
    head -50 > "${INDEX_FILE%/*}/function-list.txt"

echo "📍 Sample functions saved to: ${INDEX_FILE%/*}/function-list.txt"