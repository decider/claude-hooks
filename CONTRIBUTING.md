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
   touch hooks/my_new_hook.py
   chmod +x hooks/my_new_hook.py
   ```

2. **Integrate with universal hooks**
   Add your validation logic to the appropriate universal hook:
   - `universal-pre-tool.py` for pre-execution validation
   - `universal-post-tool.py` for post-execution checks
   - `universal-stop.py` for session completion tasks

3. **Create tests** for your hook logic
   ```python
   # tests/test_my_new_hook.py
   import unittest
   from hooks.my_new_hook import validate_something
   
   class TestMyNewHook(unittest.TestCase):
       def test_validation(self):
           # Your test code here
           pass
   ```

4. **Update documentation**
   - Add to the hooks list in README.md
   - Add detailed documentation to docs/README.md

## Code Style

### Python Scripts
- Follow PEP 8 style guide
- Use type hints where appropriate
- Add docstrings to functions
- Keep functions under 50 lines
- Use meaningful variable names

### Example Hook Structure
```python
#!/usr/bin/env python3
"""
Hook: My New Hook
Purpose: Does something amazing
Author: Your Name
"""

import json
import sys
from typing import Dict, Any

def validate_something(event_data: Dict[str, Any]) -> bool:
    """Validate something based on event data.
    
    Args:
        event_data: The event data from Claude
        
    Returns:
        bool: True if valid, False otherwise
    """
    # Your validation logic here
    return True

def main():
    """Main entry point for the hook."""
    try:
        # Read event data from stdin
        event_data = json.loads(sys.stdin.read())
        
        # Perform validation
        if not validate_something(event_data):
            print("❌ Validation failed")
            sys.exit(1)
            
        print("✅ Validation passed")
        
    except Exception as e:
        print(f"❌ Hook error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
```

## Testing

Test your hooks thoroughly:

```bash
# Run Python tests
python -m pytest tests/

# Test hook manually
echo '{"tool_name": "Bash", "tool_input": {"command": "test"}}' | python3 hooks/my_new_hook.py
```

## Pull Request Process

1. Update the README.md with details of changes
2. Update documentation as needed
3. Ensure all tests pass
4. The PR will be merged once you have the sign-off of at least one maintainer

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