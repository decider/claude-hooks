# Claude Code Hook Tests

This directory contains tests for the Claude Code hooks used in this project.

## Test Files

### `test-all-hooks.sh`
Comprehensive automated test suite that tests ALL configured hooks by simulating Claude Code's hook input format. Tests package age, code quality, git commits, and more.

**Usage:**
```bash
./claude/hooks/test-all-hooks.sh
```

### `test-claude-context-updater.sh`
Comprehensive test suite specifically for the claude-context-updater.sh hook that validates the 3 core functions: directory detection, CLAUDE.md creation, and content updates.

**Usage:**
```bash
./claude/hooks/test-claude-context-updater.sh
```

**What it tests:**
- Directory detection logic (complex vs simple directories)
- CLAUDE.md creation with real project analysis
- Content quality (project structure, components, commands)
- Updates to existing CLAUDE.md files
- Template generation with architecture detection

### `test-hooks-live.sh`
Interactive test guide that provides Claude Code commands to test all hooks in action. Run this to get a list of commands to execute through Claude.

**Usage:**
```bash
./claude/hooks/test-hooks-live.sh
```

### `test-package-age-automated.sh`
Focused test suite that verifies the package age hook behavior specifically.

**Usage:**
```bash
# Run from project root
./claude/hooks/test-package-age-automated.sh
```

**What it tests:**
- Old npm packages are blocked (exit code 2)
- Recent packages are allowed (exit code 0)
- Yarn commands are handled correctly
- Non-package commands are ignored
- Git URLs and local paths are allowed
- Multiple package installs with one old package are blocked
- Only Bash tool commands are processed

### `test-hooks-integration.sh`
Interactive test guide for manually testing hooks through Claude Code.

**Usage:**
```bash
./claude/hooks/test-hooks-integration.sh
```

This will guide you through manual tests where you run actual npm commands to verify the hooks are working in Claude Code.

### `test-package-age-hook.sh`
Direct unit tests for the package age validation logic.

## Running Tests

The automated tests can be run directly from the command line. They simulate the exact JSON input that Claude Code sends to hooks.

To run all automated tests:
```bash
cd /path/to/project
./claude/hooks/test-package-age-automated.sh
```

## Expected Test Results

When the hooks are working correctly:

1. **Old packages blocked**: `npm install left-pad@1.0.0` → Exit code 2 with "too old" error
2. **Recent packages allowed**: `npm install commander` → Exit code 0
3. **Non-Bash tools ignored**: Write/Edit commands → Exit code 0
4. **Environment overrides work**: `MAX_AGE_DAYS=10000 npm install old-package` → Exit code 0

## Test Output

A successful test run will show:
```
✓ PASSED: Block old npm package (left-pad@1.0.0)
✓ PASSED: Allow recent npm package
✓ PASSED: Block old yarn package
...
All tests passed! 🎉
```

## Hook Coverage

The test suites cover all active hooks:

| Hook | Purpose | Test Coverage |
|------|---------|---------------|
| `check-package-age.sh` | Blocks old npm/yarn packages | ✅ Full coverage |
| `pre-commit-check.sh` | Runs checks before git commits | ✅ Tested |
| `code-quality-primer.sh` | Shows Clean Code reminders | ✅ Tested |
| `code-similarity-check.sh` | Detects duplicate code | ✅ Tested |
| `post-write.sh` | Validates after file writes | ✅ Tested |
| `claude-context-updater.sh` | Updates CLAUDE.md | ✅ Tested |
| `pre-completion-check.sh` | Runs before todo completion | ✅ Tested |

## Troubleshooting

If tests fail:
1. Ensure you're running from the project root
2. Check that the hook files are executable: `chmod +x claude/hooks/*.sh`
3. Verify hooks are in the correct location: `claude/hooks/`
4. Check hook logs in `/tmp/` (various log files)
5. Ensure Claude Code has been restarted after hook changes

## Adding New Tests

To add a new test case to the automated suite:

```bash
test_hook \
    "Test description" \
    "command to test" \
    expected_exit_code \
    "expected output pattern"
```

Example:
```bash
test_hook \
    "Block scoped package with old version" \
    "npm install @babel/core@7.0.0" \
    2 \
    "too old"
```