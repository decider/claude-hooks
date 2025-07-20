# Clean Code Quality System for Claude Code

This system enforces Uncle Bob's Clean Code principles and promotes code reuse through Claude Code hooks.

## Overview

The system consists of three main hooks that work together:

1. **Pre-Hook (code quality validation in universal-post-tool.py)**: Validates code against Clean Code rules
2. **Code Quality Validator (code_quality_validator.py)**: Enforces clean code standards
3. **Validation Library (validators.py)**: Shared validation functions

## Clean Code Rules

Based on `clean-code-rules.json`:

### Size Limits
- **Functions**: Max 50 lines (promotes single responsibility)
- **Files**: Max 300 lines
- **Nesting**: Max 4 levels deep
- **Line Length**: Max 120 characters
- **Cyclomatic Complexity**: Max 10

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
The Python-based validator runs automatically on file edits.

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

Edit the validation constants in `hooks/validators.py` to adjust thresholds:

```python
# In validators.py
MAX_FUNCTION_LENGTH = 50  # Adjust function size limit
MAX_FILE_LENGTH = 300     # Adjust file size limit
MAX_NESTING_DEPTH = 4     # Adjust nesting limit
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
# Test the validator manually
echo '{"tool_name": "Edit", "file_path": "test.py"}' | python3 .claude/hooks/universal-post-tool.py

# Run the installer to update hooks
python3 install-hooks.py
```

## Troubleshooting

### Hooks not triggering
Ensure your `.claude/settings.json` includes the hook configuration. Run `python3 install-hooks.py` to set up.

### Too many false positives
Adjust thresholds in `hooks/validators.py`.

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