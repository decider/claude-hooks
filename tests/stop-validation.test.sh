#!/bin/bash

# Test suite for stop-validation.sh hook
# Tests various scenarios including single projects, monorepos, and error conditions

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Hook under test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/../hooks/stop-validation.sh"

# Simple assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ $message (expected: $expected, got: $actual)${NC}"
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [ "$not_expected" != "$actual" ]; then
        echo -e "  ${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ $message (should not be: $not_expected)${NC}"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Should contain pattern}"
    
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ $message (pattern not found: $needle)${NC}"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Should not contain pattern}"
    
    if ! echo "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ $message (pattern found: $needle)${NC}"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ $message (file not found: $file)${NC}"
        return 1
    fi
}

assert_executable() {
    local file="$1"
    local message="${2:-File should be executable}"
    
    if [ -x "$file" ]; then
        echo -e "  ${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ $message (file not executable: $file)${NC}"
        return 1
    fi
}

assert_empty() {
    local value="$1"
    local message="${2:-Value should be empty}"
    
    if [ -z "$value" ]; then
        echo -e "  ${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "  ${RED}✗ $message (value not empty: $value)${NC}"
        return 1
    fi
}

# Run a test
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TOTAL_TESTS++))
    echo -e "\n${BLUE}Test $TOTAL_TESTS: $test_name${NC}"
    
    if $test_function; then
        ((PASSED_TESTS++))
    else
        ((FAILED_TESTS++))
    fi
}

# Test: Hook exists and is executable
test_hook_exists() {
    assert_file_exists "$HOOK_PATH" "stop-validation.sh should exist"
    assert_executable "$HOOK_PATH" "stop-validation.sh should be executable"
}

# Test: Hook handles stop_hook_active flag
test_stop_hook_active() {
    # Disable logging for this test to avoid output
    export CLAUDE_LOG_ENABLED=false
    
    local input='{"stop_hook_active": true}'
    local output=$(echo "$input" | "$HOOK_PATH" 2>&1)
    local exit_code=$?
    
    assert_equals 0 "$exit_code" "Should exit 0 when stop_hook_active is true"
    # Don't check for empty output since logging might produce some
    
    # Re-enable logging
    unset CLAUDE_LOG_ENABLED
}

# Test: No TypeScript projects found
test_no_typescript_projects() {
    # Create temp directory without TypeScript
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Create a non-TypeScript project
    echo '{"name": "test", "version": "1.0.0"}' > package.json
    
    local input='{}'
    local output=$(echo "$input" | "$HOOK_PATH" 2>&1)
    local exit_code=$?
    
    assert_equals 0 "$exit_code" "Should exit 0 when no TypeScript projects found"
    
    cd - > /dev/null
    rm -rf "$test_dir"
}

# Test: Single TypeScript project with no errors
test_single_project_success() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Create TypeScript project
    cat > package.json << 'EOF'
{
  "name": "test-project",
  "scripts": {
    "typecheck": "echo 'TypeScript check passed'",
    "lint": "echo 'Lint check passed'"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    
    touch tsconfig.json
    
    local input='{}'
    local output=$(echo "$input" | "$HOOK_PATH" 2>&1)
    local exit_code=$?
    
    assert_equals 0 "$exit_code" "Should exit 0 when all checks pass"
    
    cd - > /dev/null
    rm -rf "$test_dir"
}

# Test: Single TypeScript project with errors
test_single_project_with_errors() {
    # Disable logging for cleaner test output
    export CLAUDE_LOG_ENABLED=false
    
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Create TypeScript project with failing checks
    cat > package.json << 'EOF'
{
  "name": "test-project",
  "scripts": {
    "typecheck": "echo 'error TS2307: Cannot find module' >&2 && exit 1",
    "lint": "echo 'Lint errors found' >&2 && exit 1"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    
    touch tsconfig.json
    
    local input='{}'
    local output=$(echo "$input" | "$HOOK_PATH" 2>&1)
    local exit_code=$?
    
    assert_equals 1 "$exit_code" "Should exit 1 when checks fail"
    assert_contains "$output" '"decision": "block"' "Should output block decision"
    assert_contains "$output" "TypeScript errors:" "Should mention TypeScript errors"
    
    cd - > /dev/null
    rm -rf "$test_dir"
    unset CLAUDE_LOG_ENABLED
}

# Test: Monorepo with multiple packages
test_monorepo_detection() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Create monorepo structure
    mkdir -p apps/web apps/api packages/shared
    
    # Root package.json with workspaces
    cat > package.json << 'EOF'
{
  "name": "monorepo",
  "workspaces": ["apps/*", "packages/*"]
}
EOF
    
    # Web app
    cat > apps/web/package.json << 'EOF'
{
  "name": "web",
  "scripts": {
    "typecheck": "echo 'Web typecheck passed'"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    touch apps/web/tsconfig.json
    
    # API app
    cat > apps/api/package.json << 'EOF'
{
  "name": "api",
  "scripts": {
    "typecheck": "echo 'API typecheck passed'"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    touch apps/api/tsconfig.json
    
    # Shared package
    cat > packages/shared/package.json << 'EOF'
{
  "name": "shared",
  "scripts": {
    "typecheck": "echo 'Shared typecheck passed'"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    touch packages/shared/tsconfig.json
    
    local input='{}'
    local output=$(echo "$input" | "$HOOK_PATH" 2>&1)
    local exit_code=$?
    
    assert_equals 0 "$exit_code" "Should exit 0 when all monorepo checks pass"
    
    cd - > /dev/null
    rm -rf "$test_dir"
}

# Test: Mixed success and failure in monorepo
test_monorepo_partial_failure() {
    export CLAUDE_LOG_ENABLED=false
    
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    mkdir -p apps/web apps/api
    
    # Web app - success
    cat > apps/web/package.json << 'EOF'
{
  "name": "web",
  "scripts": {
    "typecheck": "echo 'Web typecheck passed'"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    touch apps/web/tsconfig.json
    
    # API app - failure
    cat > apps/api/package.json << 'EOF'
{
  "name": "api",
  "scripts": {
    "typecheck": "echo 'error TS2307: Cannot find module @solana/web3.js' >&2 && exit 1"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    touch apps/api/tsconfig.json
    
    local input='{}'
    local output=$(echo "$input" | "$HOOK_PATH" 2>&1)
    local exit_code=$?
    
    assert_equals 1 "$exit_code" "Should exit 1 when any check fails"
    assert_contains "$output" '"decision": "block"' "Should output block decision"
    assert_contains "$output" "api: 1 errors" "Should show which package failed"
    
    cd - > /dev/null
    rm -rf "$test_dir"
    unset CLAUDE_LOG_ENABLED
}

# Test: TypeScript without custom script
test_typescript_no_custom_script() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Create TypeScript project without typecheck script
    cat > package.json << 'EOF'
{
  "name": "test-project",
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    
    cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "noEmit": true,
    "strict": true
  }
}
EOF
    
    # Create a simple TypeScript file
    echo 'const x: string = "hello";' > test.ts
    
    # Install TypeScript locally for test
    npm install --no-save typescript &>/dev/null || true
    
    local input='{}'
    local output=$(echo "$input" | "$HOOK_PATH" 2>&1)
    local exit_code=$?
    
    # Should attempt to use tsc directly
    assert_equals 0 "$exit_code" "Should handle projects without custom scripts"
    
    cd - > /dev/null
    rm -rf "$test_dir"
}

# Test: JSON parsing of hook input
test_json_input_parsing() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Malformed JSON should not crash
    local output=$(echo "not json" | "$HOOK_PATH" 2>&1)
    local exit_code=$?
    
    # Hook should handle gracefully
    assert_not_equals 2 "$exit_code" "Should not exit with code 2 on bad JSON"
    
    cd - > /dev/null
    rm -rf "$test_dir"
}

# Test: Excludes node_modules and build directories
test_excludes_build_directories() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Create structure with node_modules
    mkdir -p src node_modules/some-package dist
    
    # Main project
    cat > package.json << 'EOF'
{
  "name": "main",
  "scripts": {
    "typecheck": "echo 'Main typecheck passed'"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    touch tsconfig.json
    
    # Should ignore this
    cat > node_modules/some-package/package.json << 'EOF'
{
  "name": "ignored",
  "scripts": {
    "typecheck": "echo 'Should not run' && exit 1"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
EOF
    touch node_modules/some-package/tsconfig.json
    
    local input='{}'
    local output=$(echo "$input" | "$HOOK_PATH" 2>&1)
    local exit_code=$?
    
    assert_equals 0 "$exit_code" "Should ignore node_modules"
    assert_not_contains "$output" "Should not run" "Should not run checks in node_modules"
    
    cd - > /dev/null
    rm -rf "$test_dir"
}

# Main test runner
echo "========================================"
echo "Stop Validation Hook Test Suite"
echo "========================================"

# Run all tests
run_test "Hook exists and is executable" test_hook_exists
run_test "Handles stop_hook_active flag" test_stop_hook_active
run_test "No TypeScript projects found" test_no_typescript_projects
run_test "Single TypeScript project with no errors" test_single_project_success
run_test "Single TypeScript project with errors" test_single_project_with_errors
run_test "Monorepo detection" test_monorepo_detection
run_test "Mixed success and failure in monorepo" test_monorepo_partial_failure
run_test "TypeScript without custom script" test_typescript_no_custom_script
run_test "JSON parsing of hook input" test_json_input_parsing
run_test "Excludes node_modules and build directories" test_excludes_build_directories

# Summary
echo -e "\n========================================"
echo -e "${BLUE}Test Summary${NC}"
echo "========================================"
echo -e "Total tests: $TOTAL_TESTS"
echo -e "Passed:      ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:      ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi