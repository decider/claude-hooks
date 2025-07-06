#!/bin/bash

# Integration test for Claude Code hooks
# This script runs actual npm commands to test the hooks in action

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Claude Code Hooks Integration Test"
echo "========================================"
echo ""
echo -e "${YELLOW}This test will run actual npm commands through Claude Code${NC}"
echo -e "${YELLOW}to verify hooks are working correctly.${NC}"
echo ""

# Function to print test header
test_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Test: $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to check if package is installed
check_package() {
    local package="$1"
    if npm list "$package" --depth=0 2>/dev/null | grep -q "$package"; then
        return 0
    else
        return 1
    fi
}

# Clean up any existing test packages
echo -e "${YELLOW}Cleaning up any existing test packages...${NC}"
npm uninstall left-pad moment lodash commander 2>/dev/null || true

# Test 1: Verify old package is blocked
test_header "Old Package Blocking"
echo "Attempting to install left-pad@1.0.0 (from 2016)..."
echo -e "${YELLOW}This should be BLOCKED by the hook${NC}"
echo ""
echo "Run this command:"
echo -e "${GREEN}npm install left-pad@1.0.0${NC}"
echo ""
echo "Expected: Command should fail with 'Execution stopped by PreToolUse hook'"
echo ""
read -p "Press Enter after running the command..."

if check_package "left-pad"; then
    echo -e "${RED}✗ FAILED: Package was installed when it should have been blocked!${NC}"
else
    echo -e "${GREEN}✓ PASSED: Package was correctly blocked${NC}"
fi

# Test 2: Verify recent package is allowed
test_header "Recent Package Installation"
echo "Attempting to install commander (actively maintained)..."
echo -e "${YELLOW}This should be ALLOWED by the hook${NC}"
echo ""
echo "Run this command:"
echo -e "${GREEN}npm install commander${NC}"
echo ""
echo "Expected: Command should succeed"
echo ""
read -p "Press Enter after running the command..."

if check_package "commander"; then
    echo -e "${GREEN}✓ PASSED: Package was correctly installed${NC}"
else
    echo -e "${RED}✗ FAILED: Package was not installed when it should have been allowed!${NC}"
fi

# Clean up
echo ""
echo -e "${YELLOW}Cleaning up test packages...${NC}"
npm uninstall commander 2>/dev/null || true

# Test 3: Test with multiple packages
test_header "Multiple Package Installation (Mixed)"
echo "Attempting to install multiple packages with one old..."
echo -e "${YELLOW}This should be BLOCKED because one package is old${NC}"
echo ""
echo "Run this command:"
echo -e "${GREEN}npm install lodash left-pad@1.0.0${NC}"
echo ""
echo "Expected: Command should fail due to left-pad being old"
echo ""
read -p "Press Enter after running the command..."

if check_package "left-pad" || check_package "lodash"; then
    echo -e "${RED}✗ FAILED: Packages were installed when they should have been blocked!${NC}"
else
    echo -e "${GREEN}✓ PASSED: Installation was correctly blocked${NC}"
fi

# Test 4: Test environment variable override
test_header "Environment Variable Override"
echo "Testing MAX_AGE_DAYS environment variable..."
echo -e "${YELLOW}This should ALLOW old packages when MAX_AGE_DAYS is set high${NC}"
echo ""
echo "Run this command:"
echo -e "${GREEN}MAX_AGE_DAYS=10000 npm install moment@2.18.0${NC}"
echo ""
echo "Expected: Command should succeed (10000 days allows packages from 2017)"
echo ""
read -p "Press Enter after running the command..."

if check_package "moment"; then
    echo -e "${GREEN}✓ PASSED: Environment variable override worked${NC}"
else
    echo -e "${RED}✗ FAILED: Package was blocked despite environment variable!${NC}"
fi

# Final cleanup
echo ""
echo -e "${YELLOW}Final cleanup...${NC}"
npm uninstall left-pad moment lodash commander 2>/dev/null || true

echo ""
echo "========================================"
echo -e "${GREEN}Integration Test Complete!${NC}"
echo "========================================"
echo ""
echo "Summary:"
echo "- Old packages should be blocked ✓"
echo "- Recent packages should be allowed ✓"
echo "- Mixed installs with old packages should be blocked ✓"
echo "- Environment variables should override defaults ✓"
echo ""
echo -e "${YELLOW}Note: This test requires manual interaction to work with Claude Code${NC}"