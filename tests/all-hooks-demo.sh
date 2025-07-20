#!/bin/bash
# Demonstration of all hooks using continue: false

echo "=== Demonstration: All Hooks with continue: false ==="
echo

# Test each hook's JSON output
echo "1. code-quality-validator.sh"
echo "----------------------------"
# Simulate a quality violation
echo '{"tool":"Write","tool_input":{"file_path":"/tmp/bad.js"},"exit_code":0}' | ./hooks/code-quality-validator.sh 2>&1 | grep -A5 -B5 '"continue"' || echo "Would output JSON on violations"
echo

echo "2. lint-check.sh" 
echo "----------------"
echo "When lint fails, outputs:"
cat << 'EOF'
{
  "continue": false,
  "stopReason": "Code has linting errors - cannot proceed",
  "decision": "block", 
  "reason": "Linting errors found. Please fix these issues:\n\n• eslint errors...\n\nTo fix: npm run lint:fix"
}
EOF
echo

echo "3. test-check.sh"
echo "----------------"
echo "When tests fail, outputs:"
cat << 'EOF'
{
  "continue": false,
  "stopReason": "Tests are failing - cannot proceed",
  "decision": "block",
  "reason": "3 tests are failing. Please fix these test failures:\n\n• test1.spec.js\n• test2.spec.js\n\nRun 'npm test' to see full output."
}
EOF
echo

echo "4. typescript-check.sh"
echo "---------------------"
echo "When TypeScript errors exist, outputs:"
cat << 'EOF'
{
  "continue": false,
  "stopReason": "TypeScript compilation errors - cannot proceed",
  "decision": "block",
  "reason": "Found 5 TypeScript errors. Please fix these type errors:\n\n• src/index.ts:42 - Type 'string' not assignable to 'number'\n\nRun 'npm run typecheck' to see all errors."
}
EOF
echo

echo "5. doc-compliance.sh (Stop event)"
echo "---------------------------------"
echo "When documentation standards not met:"
cat << 'EOF'
{
  "continue": false,
  "stopReason": "Documentation standards not met (score: 0.6/0.8)",
  "decision": "block",
  "reason": "Documentation compliance failed. Issues to fix:\n• Missing function documentation\n• Update README"
}
EOF
echo

echo "6. check-package-age.sh"
echo "----------------------"
echo '{"tool_name":"Bash","tool_input":{"command":"npm install left-pad@1.0.0"}}' | ./hooks/check-package-age.sh 2>&1 | grep -A5 '"continue"' || echo "Would block old packages"
echo

echo "=== How It Works ==="
echo "1. Hook detects issue (lint error, test failure, etc.)"
echo "2. Outputs JSON with continue: false to stdout"
echo "3. Universal-hook captures and parses JSON"
echo "4. Sees continue: false and exits with code 2"
echo "5. Claude Code sees exit 2 and blocks operation"
echo "6. User sees stopReason message"
echo "7. Claude sees reason with fix instructions"
echo
echo "✅ All hooks now support checkpoint workflows!"