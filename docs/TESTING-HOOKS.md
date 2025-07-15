# Testing Hooks with Claude

This document explains how to use the built-in testing mechanism for Claude hooks, enabling Claude to automatically test and validate hooks during development.

## Overview

The testing framework provides:
- **Logging infrastructure** - Detailed logs for hook execution
- **Pre/Post Write events** - Test hooks immediately when files are written
- **Self-test hook** - Claude can trigger tests automatically
- **Test runner** - Validate hooks with specific test cases
- **Continuous mode** - Watch for changes and re-run tests

## Quick Start

### 1. Enable verbose logging
```bash
# Run any hook with verbose logging
CLAUDE_HOOK_VERBOSE=true npx claude-code-hooks-cli exec doc-compliance

# Or enable in test mode
npx claude-code-hooks-cli test --verbose
```

### 2. Run tests for a specific hook
```bash
# Test the doc-compliance hook
npx claude-code-hooks-cli test --hook doc-compliance

# Test all hooks for a specific event
npx claude-code-hooks-cli test --event Stop
```

### 3. Continuous testing mode
```bash
# Watch for changes and re-run tests
npx claude-code-hooks-cli test --watch

# Continuous mode with verbose output
npx claude-code-hooks-cli test --continuous --verbose
```

## Claude Self-Testing Workflow

Claude can now test hooks automatically during development:

### 1. Create a test configuration
Claude creates a JSON file describing what to test:
```json
{
  "hookToTest": "doc-compliance",
  "testCommand": "npm run test -- --hook doc-compliance",
  "expectedOutput": "✅",
  "expectSuccess": true
}
```

### 2. Trigger the test
Claude writes a `.test-trigger` file, which automatically:
- Runs the specified test command
- Validates the output
- Creates a `.test-result` file with results
- Blocks the write if tests fail

### 3. Evaluate results
Claude reads the `.test-result` file to see:
- Whether tests passed
- Execution time
- Any failure reasons
- Test output

## Example: Testing Doc-Compliance Hook

Here's how Claude would test the doc-compliance hook:

```typescript
// 1. Claude creates test configuration
const testConfig = {
  hookToTest: "doc-compliance",
  testCommand: "npx claude-code-hooks-cli test --hook doc-compliance",
  expectedOutput: "passed",
  expectSuccess: true
};

// 2. Claude writes the config
fs.writeFileSync('.claude/test-doc-compliance.json', JSON.stringify(testConfig));

// 3. Claude triggers the test (this activates the self-test hook)
fs.writeFileSync('.claude/test-doc-compliance.test-trigger', '');

// 4. Claude reads the results
const results = JSON.parse(fs.readFileSync('.claude/test-doc-compliance.test-result'));
if (results.success) {
  console.log('✅ Hook is working correctly');
} else {
  console.log('❌ Hook failed:', results.failureReason);
  // Claude can now fix the issue and re-test
}
```

## Writing Test Cases

Create test cases in `.claude/tests/`:

```typescript
// .claude/tests/my-hook.test.ts
import { TestCase } from 'claude-code-hooks-cli/testing';

const testCases: TestCase[] = [
  {
    name: 'Hook triggers on correct event',
    hook: 'my-hook',
    event: {
      event: 'PreWrite',
      filePath: '/tmp/test.txt'
    },
    expect: {
      shouldRun: true,
      exitCode: 0,
      outputContains: ['Success'],
      duration: { max: 5000 }
    }
  }
];

export default testCases;
```

## Logging

Logs are automatically saved to `.claude/logs/`:
- `hooks-YYYY-MM-DD.log` - Daily log files
- Includes timestamps, event types, hook names, and durations
- Errors and warnings are always logged
- Use `--verbose` to see all debug logs

## Pre/Post Write Events

The new `PreWrite` and `PostWrite` events allow immediate testing:

```json
{
  "hooks": {
    "PreWrite": [{
      "pattern": "\\.test$",
      "hooks": [{
        "type": "command",
        "command": "echo 'About to write test file'"
      }]
    }],
    "PostWrite": [{
      "pattern": "\\.test$",
      "hooks": [{
        "type": "command", 
        "command": "echo 'Test file written'"
      }]
    }]
  }
}
```

## Benefits for Claude Development

1. **Faster iteration** - Test hooks immediately without manual intervention
2. **Automatic validation** - Ensure hooks work before committing changes
3. **Clear feedback** - Detailed logs and test results
4. **Self-correcting** - Claude can fix issues and re-test automatically
5. **Continuous testing** - Keep tests running while developing

## Tips

1. Always check logs when a hook fails: `.claude/logs/`
2. Use verbose mode during development
3. Create specific test cases for edge cases
4. Test with different file types and events
5. Use continuous mode when making multiple changes