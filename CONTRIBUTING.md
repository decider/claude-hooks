# Contributing to Claude Hooks

We love your input! We want to make contributing to Claude Hooks as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Process

We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code follows the existing style
6. Issue that pull request!

## Adding a New Hook

To add a new hook:

1. **Create the hook script** in `hooks/`
   ```bash
   touch hooks/my-new-hook.sh
   chmod +x hooks/my-new-hook.sh
   ```

2. **Add hook configuration** to `config/settings.example.json`
   ```json
   {
     "matcher": "YourMatcher",
     "hooks": [{
       "type": "command",
       "command": "~/.claude/hooks/my-new-hook.sh"
     }]
   }
   ```

3. **Create tests** in `tests/`
   ```bash
   touch tests/test-my-new-hook.sh
   chmod +x tests/test-my-new-hook.sh
   ```

4. **Update documentation**
   - Add to the hooks table in README.md
   - Add detailed documentation to docs/README.md

## Code Style

### Shell Scripts
- Use `#!/bin/bash` shebang
- Set `set -euo pipefail` for error handling
- Use meaningful variable names
- Add comments for complex logic
- Follow existing code patterns

### Example Hook Structure
```bash
#!/bin/bash
set -euo pipefail

# Hook: My New Hook
# Purpose: Does something amazing
# Author: Your Name

# Configuration
DEFAULT_VALUE="${MY_HOOK_VALUE:-default}"

# Main logic
main() {
    echo "🚀 Running my new hook..."
    # Your code here
}

# Run main function
main "$@"
```

## Testing

All hooks must have tests:

```bash
# Run all tests
cd tests
./test-all-hooks.sh

# Run specific test
./test-my-new-hook.sh
```

## Pull Request Process

1. Update the README.md with details of changes to the interface
2. Update the VERSION file with the new version number
3. The PR will be merged once you have the sign-off of at least one maintainer

## Any contributions you make will be under the MIT Software License

When you submit code changes, your submissions are understood to be under the same [MIT License](LICENSE) that covers the project.

## Report bugs using GitHub's [issue tracker](https://github.com/your-org/claude-hooks/issues)

We use GitHub issues to track public bugs. Report a bug by [opening a new issue](https://github.com/your-org/claude-hooks/issues/new).

**Great Bug Reports** tend to have:
- A quick summary and/or background
- Steps to reproduce
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening)

## License

By contributing, you agree that your contributions will be licensed under its MIT License.