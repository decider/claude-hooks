# Python Coding Standards

## General Principles
- Follow PEP 8 style guide
- Use type hints for better code clarity
- Write self-documenting code with clear variable names
- Keep functions focused on a single responsibility

## Naming Conventions
- Use snake_case for variables and functions
- Use PascalCase for classes
- Use UPPER_SNAKE_CASE for constants
- Use descriptive names that explain purpose

## Functions
- Keep functions under 50 lines
- Limit function parameters to 5 maximum
- Use keyword arguments for optional parameters
- Document complex functions with docstrings

## Error Handling
- Always handle exceptions appropriately
- Use specific exception types
- Provide meaningful error messages
- Log errors for debugging

## Code Organization
- One class per file when it makes sense
- Group related functionality in modules
- Keep files under 300 lines
- Use `__init__.py` for clean imports

## Hook-Specific Guidelines
- Read event data from stdin
- Output messages to stdout
- Use exit codes: 0 for success, 1 for blocking
- Keep hooks fast and focused

## Example
```python
# Good
import json
import sys
from typing import Dict, Any

def validate_command(event_data: Dict[str, Any]) -> bool:
    """Validate a command before execution.
    
    Args:
        event_data: The event data from Claude
        
    Returns:
        bool: True if command is valid, False otherwise
    """
    tool_name = event_data.get('tool_name', '')
    if tool_name != 'Bash':
        return True
        
    command = event_data.get('tool_input', {}).get('command', '')
    if 'rm -rf /' in command:
        print("❌ Dangerous command blocked")
        return False
    
    return True

# Bad
def validate(data):
    if data['tool_name'] == 'Bash':
        cmd = data['tool_input']['command']
        if 'rm -rf /' in cmd:
            print("bad")
            return False
    return True
```