# Clean Code Quality System for Claude Code

This system enforces Uncle Bob's Clean Code principles and promotes code reuse through Claude Code hooks.

## Overview

The system consists of three main hooks that work together:

1. **Pre-Hook (code-quality-primer.sh)**: Reminds about Clean Code principles and checks for existing code
2. **Post-Hook (code-quality-validator.sh)**: Validates code against Clean Code rules
3. **Code Index (build-code-index.sh)**: Maintains searchable index of functions/utilities

## Clean Code Rules

Based on `clean-code-rules.json`:

### Size Limits
- **Functions**: Max 20 lines (promotes single responsibility)
- **Files**: Max 100 lines (150 for components)
- **Classes**: Max 5 public methods
- **Parameters**: Max 3 per function
- **Nesting**: Max 3 levels deep
- **Line Length**: Max 80 characters

### Code Quality Checks
- **Magic Numbers**: Must use named constants (except 0, 1, -1)
- **Comments**: Max 20% comment ratio (code should be self-documenting)
- **Duplication**: Flags repeated patterns (>5 occurrences)
- **Cyclomatic Complexity**: Max 5 (kept simple for deterministic checking)

### DRY (Don't Repeat Yourself)
The system actively prevents code duplication by:
- Checking for similar function names before creation
- Suggesting existing utilities from common libraries
- Maintaining an index of all project functions
- Warning about common patterns that already exist

## How It Works

### 1. Before Writing Code
When Claude creates/edits code files, the primer hook:
- Injects language-specific Clean Code reminders
- Searches for similar existing functions
- Suggests utilities from lodash, date-fns, etc.
- Reminds about DRY principle

### 2. After Writing Code
The validator hook checks:
- Function and file lengths
- Nesting depth and complexity
- Line length violations
- Magic numbers
- Comment density
- Repeated patterns

### 3. Code Index
Build the index periodically:
```bash
./claude/hooks/build-code-index.sh
```

This creates a searchable database of:
- All exported functions with locations
- React components
- Custom hooks
- TypeScript types and interfaces
- Utility directory locations

## Common Warnings and Solutions

### "Function too long: 25 lines (max: 20)"
**Solution**: Extract helper functions. Each function should do ONE thing.

### "Similar existing functions found"
**Solution**: Import and use the existing function instead of creating a duplicate.

### "Magic numbers detected"
**Solution**: Extract to named constants at the top of the file.

### "Excessive nesting: depth 4 (max: 3)"
**Solution**: Use early returns, extract complex conditions to functions.

### "High comment ratio: 0.3"
**Solution**: Refactor code to be self-documenting with better names.

## Customizing Rules

Edit `./claude/hooks/clean-code-rules.json` to adjust thresholds:

```json
{
  "rules": {
    "maxFunctionLines": 20,  // Adjust function size limit
    "maxFileLines": 100,     // Adjust file size limit
    "similarityThreshold": 0.8  // How similar before warning
  }
}
```

## Best Practices

1. **Run the indexer** regularly: `./claude/hooks/build-code-index.sh`
2. **Check before creating**: Always verify similar code doesn't exist
3. **Prefer composition**: Small functions composed together
4. **Use descriptive names**: `calculateUserTotalScore` not `calc`
5. **Extract constants**: `const MAX_RETRIES = 3` not magic `3`
6. **One responsibility**: Each function/class does one thing well

## Quick Commands

```bash
# Build/rebuild the code index
./claude/hooks/build-code-index.sh

# Look up a function quickly
./claude/hooks/lookup-function.sh formatDate

# Check similarity of code snippet
echo "function debounce(fn, delay) {}" | ./claude/hooks/code-similarity-check.sh -
```

## Troubleshooting

### Hooks not triggering
Ensure your `./claude/settings.json` includes the hook configuration.

### Too many false positives
Adjust thresholds in `clean-code-rules.json`.

### Index out of date
Run the indexer more frequently or add it to a cron job.

## Philosophy

> "Clean code is simple and direct. Clean code reads like well-written prose."
> - Robert C. Martin

The goal is not just to write code that works, but code that is:
- Easy to understand
- Easy to modify
- Easy to test
- Reusable

By enforcing these principles automatically, we ensure consistent, high-quality code across the entire codebase.