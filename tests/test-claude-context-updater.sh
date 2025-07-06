#!/bin/bash

# Comprehensive test suite for claude-context-updater.sh
# Tests the 3 core functions: detection, creation, and updates

set -uo pipefail
export CLAUDE_HOOKS_TEST_MODE=1

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

# Test directory
TEST_ROOT="/tmp/claude-context-tests-$$"
mkdir -p "$TEST_ROOT"

# Cleanup on exit
trap "rm -rf $TEST_ROOT" EXIT

echo "========================================"
echo "Claude Context Updater Comprehensive Tests"
echo "========================================"
echo -e "${YELLOW}Testing CLAUDE.md detection, creation, and updates${NC}"
echo ""

# Function to run a test
test_function() {
    local test_name="$1"
    local test_func="$2"
    
    ((TOTAL_TESTS++))
    
    echo -e "${BLUE}Test $TOTAL_TESTS: $test_name${NC}"
    
    if $test_func; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        ((FAILED_TESTS++))
    fi
    echo ""
}

# Helper function to create hook input JSON
create_hook_input() {
    local tool_name="$1"
    local file_path="$2"
    cat << EOF
{
  "session_id": "test-$$",
  "transcript_path": "/tmp/test.jsonl",
  "hook_event_name": "PostToolUse",
  "tool_name": "$tool_name",
  "tool_input": {
    "file_path": "$file_path",
    "content": "test content"
  }
}
EOF
}

# Helper function to run context updater
run_context_updater() {
    local input="$1"
    cd "$TEST_ROOT"
    echo "$input" | claude/hooks/claude-context-updater.sh 2>/dev/null
}

# Test 1: Directory detection - Should create CLAUDE.md for complex directories
test_directory_detection() {
    local test_dir="$TEST_ROOT/complex-module"
    mkdir -p "$test_dir"
    
    # Create enough TypeScript files to trigger CLAUDE.md creation (needs >2 files)
    echo "export const Component1 = () => {}" > "$test_dir/Component1.tsx"
    echo "export const Component2 = () => {}" > "$test_dir/Component2.tsx"
    echo "export const Component3 = () => {}" > "$test_dir/Component3.tsx"
    
    # Create package.json
    cat > "$test_dir/package.json" << 'EOF'
{
  "name": "complex-module",
  "description": "A complex React module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "test": "vitest"
  },
  "dependencies": {
    "react": "18.2.0",
    "typescript": "5.1.0"
  }
}
EOF
    
    # Run context updater
    local input=$(create_hook_input "Write" "$test_dir/Component1.tsx")
    run_context_updater "$input"
    
    # Verify CLAUDE.md was created
    if [ -f "$test_dir/CLAUDE.md" ]; then
        return 0
    else
        echo "    Expected CLAUDE.md to be created in $test_dir"
        return 1
    fi
}

# Test 2: Should NOT create CLAUDE.md for simple directories
test_directory_detection_skip() {
    local test_dir="$TEST_ROOT/simple-dir"
    mkdir -p "$test_dir"
    
    # Create only 1 file (below threshold of 2)
    echo "export const simple = () => {}" > "$test_dir/simple.ts"
    
    # Run context updater
    local input=$(create_hook_input "Write" "$test_dir/simple.ts")
    run_context_updater "$input"
    
    # Verify CLAUDE.md was NOT created
    if [ ! -f "$test_dir/CLAUDE.md" ]; then
        return 0
    else
        echo "    Expected CLAUDE.md NOT to be created for simple directory"
        return 1
    fi
}

# Test 3: Should create CLAUDE.md for directories with package.json (even with few files)
test_directory_detection_package_json() {
    local test_dir="$TEST_ROOT/package-dir"
    mkdir -p "$test_dir"
    
    # Create package.json (should trigger creation even with 1 file)
    cat > "$test_dir/package.json" << 'EOF'
{
  "name": "package-dir",
  "description": "Directory with package.json"
}
EOF
    
    echo "export const main = () => {}" > "$test_dir/index.ts"
    
    # Run context updater
    local input=$(create_hook_input "Write" "$test_dir/index.ts")
    run_context_updater "$input"
    
    # Verify CLAUDE.md was created
    if [ -f "$test_dir/CLAUDE.md" ]; then
        return 0
    else
        echo "    Expected CLAUDE.md to be created for directory with package.json"
        return 1
    fi
}

# Test 4: CLAUDE.md content quality - Project structure analysis
test_content_project_structure() {
    local test_dir="$TEST_ROOT/structured-project"
    mkdir -p "$test_dir"/{components,hooks,utils}
    
    # Create realistic project structure
    cat > "$test_dir/package.json" << 'EOF'
{
  "name": "trading-dashboard",
  "description": "Real-time trading dashboard",
  "scripts": {
    "dev": "vite --port 3000",
    "build": "tsc && vite build",
    "test": "vitest run",
    "lint": "eslint src/ --ext .ts,.tsx"
  },
  "dependencies": {
    "react": "18.2.0",
    "typescript": "5.1.0",
    "@tanstack/react-query": "4.29.0"
  }
}
EOF
    
    # Put files in the root directory so it qualifies for CLAUDE.md
    echo "export const TradingChart = () => {}" > "$test_dir/TradingChart.tsx"
    echo "export const OrderForm = () => {}" > "$test_dir/OrderForm.tsx"
    echo "export const useWebSocket = () => {}" > "$test_dir/useWebSocket.ts"
    echo "export const formatPrice = (price: number) => {}" > "$test_dir/currency.ts"
    
    # Also create subdirectories for analysis
    echo "export const Component1 = () => {}" > "$test_dir/components/Component1.tsx"
    echo "export const useHook = () => {}" > "$test_dir/hooks/useHook.ts"
    echo "export const util = () => {}" > "$test_dir/utils/util.ts"
    
    # Run context updater
    local input=$(create_hook_input "Write" "$test_dir/TradingChart.tsx")
    run_context_updater "$input"
    
    # Verify CLAUDE.md was created and has correct content
    local claude_file="$test_dir/CLAUDE.md"
    if [ ! -f "$claude_file" ]; then
        echo "    CLAUDE.md was not created"
        return 1
    fi
    
    # Check for project name (using directory name since that's what gets used)
    if ! grep -q "structured-project" "$claude_file"; then
        echo "    Missing project name"
        return 1
    fi
    
    # Check for commands section
    if ! grep -q "npm run dev" "$claude_file"; then
        echo "    Missing npm scripts"
        return 1
    fi
    
    # Check for dependencies
    if ! grep -q "@tanstack/react-query" "$claude_file"; then
        echo "    Missing dependencies"
        return 1
    fi
    
    # Check for description
    if ! grep -q "Real-time trading dashboard" "$claude_file"; then
        echo "    Missing project description"
        return 1
    fi
    
    return 0
}

# Test 5: CLAUDE.md content quality - Component detection
test_content_component_detection() {
    local test_dir="$TEST_ROOT/component-project"
    mkdir -p "$test_dir"
    
    # Create files with exports
    echo "export const MainComponent = () => {}" > "$test_dir/MainComponent.tsx"
    echo "export function UtilityFunction() {}" > "$test_dir/utils.ts"
    echo "export class DataService {}" > "$test_dir/service.ts"
    
    cat > "$test_dir/package.json" << 'EOF'
{
  "name": "component-project"
}
EOF
    
    # Run context updater
    local input=$(create_hook_input "Write" "$test_dir/MainComponent.tsx")
    run_context_updater "$input"
    
    # Verify component detection
    local claude_file="$test_dir/CLAUDE.md"
    if [ ! -f "$claude_file" ]; then
        echo "    CLAUDE.md was not created"
        return 1
    fi
    
    # Check if it detected key components
    if ! grep -q "MainComponent.tsx" "$claude_file"; then
        echo "    Missing component file detection"
        return 1
    fi
    
    return 0
}

# Test 6: CLAUDE.md updates - Commands section update
test_updates_commands_section() {
    local test_dir="$TEST_ROOT/update-test"
    mkdir -p "$test_dir"
    
    # Create initial CLAUDE.md
    cat > "$test_dir/CLAUDE.md" << 'EOF'
# update-test - CLAUDE.md

## Overview
Test project for updates

## Commands
- `npm run old-command` - Old command

## Dependencies
- old-package@1.0.0

## Architecture Notes
- Old architecture notes
EOF
    
    # Create updated package.json
    cat > "$test_dir/package.json" << 'EOF'
{
  "name": "update-test",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "test": "vitest"
  },
  "dependencies": {
    "react": "18.2.0",
    "vite": "4.3.0"
  }
}
EOF
    
    echo "export const NewComponent = () => {}" > "$test_dir/NewComponent.tsx"
    
    # Run context updater
    local input=$(create_hook_input "Write" "$test_dir/NewComponent.tsx")
    run_context_updater "$input"
    
    # Verify CLAUDE.md was updated
    local claude_file="$test_dir/CLAUDE.md"
    
    # Check that new commands are present
    if ! grep -q "npm run dev" "$claude_file"; then
        echo "    Commands section not updated"
        return 1
    fi
    
    # Check that new dependencies are present
    if ! grep -q "react@18.2.0" "$claude_file"; then
        echo "    Dependencies section not updated"
        return 1
    fi
    
    # Check that overview section was preserved
    if ! grep -q "Test project for updates" "$claude_file"; then
        echo "    Overview section was lost"
        return 1
    fi
    
    # Verify backup was created
    if [ ! -f "$claude_file.backup" ]; then
        echo "    Backup file not created"
        return 1
    fi
    
    return 0
}

# Test 7: Template generation - Architecture detection
test_template_architecture_detection() {
    local test_dir="$TEST_ROOT/arch-test"
    mkdir -p "$test_dir"
    
    # Create React component
    cat > "$test_dir/ReactComponent.tsx" << 'EOF'
import React from 'react';
export const ReactComponent = () => {
  return <div>Hello</div>;
};
EOF
    
    # Create index file
    echo "export * from './ReactComponent';" > "$test_dir/index.ts"
    
    cat > "$test_dir/package.json" << 'EOF'
{
  "name": "arch-test"
}
EOF
    
    # Run context updater
    local input=$(create_hook_input "Write" "$test_dir/ReactComponent.tsx")
    run_context_updater "$input"
    
    # Verify architecture detection
    local claude_file="$test_dir/CLAUDE.md"
    if [ ! -f "$claude_file" ]; then
        echo "    CLAUDE.md was not created"
        return 1
    fi
    
    # Check for React detection
    if ! grep -q "React components" "$claude_file"; then
        echo "    React architecture not detected"
        return 1
    fi
    
    # Check for index file detection
    if ! grep -q "Has main index file" "$claude_file"; then
        echo "    Index file not detected"
        return 1
    fi
    
    return 0
}

# Copy the hook to test directory
cp claude/hooks/claude-context-updater.sh "$TEST_ROOT/"
mkdir -p "$TEST_ROOT/claude/hooks"
cp claude/hooks/claude-context-updater.sh "$TEST_ROOT/claude/hooks/"

# Run all tests
test_function "Directory detection - Complex directories" test_directory_detection
test_function "Directory detection - Skip simple directories" test_directory_detection_skip  
test_function "Directory detection - Package.json directories" test_directory_detection_package_json
test_function "Content quality - Project structure analysis" test_content_project_structure
test_function "Content quality - Component detection" test_content_component_detection
test_function "Updates - Commands and dependencies sections" test_updates_commands_section
test_function "Template generation - Architecture detection" test_template_architecture_detection

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    echo -e "${GREEN}Claude Context Updater is working correctly:${NC}"
    echo -e "  ✅ Detects directories that need CLAUDE.md"
    echo -e "  ✅ Creates quality CLAUDE.md content with real project info"
    echo -e "  ✅ Updates existing CLAUDE.md files when projects change"
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the claude-context-updater.sh implementation.${NC}"
    exit 1
fi