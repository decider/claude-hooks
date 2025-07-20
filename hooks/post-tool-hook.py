#!/usr/bin/env python3
"""Direct PostToolUse Hook Handler.

Processes PostToolUse events for Write/Edit/MultiEdit operations.
"""

import json
import sys
import subprocess
import os

def print_continue():
    """Print continue action."""
    print(json.dumps({"action": "continue"}))

def parse_input():
    """Parse input from stdin."""
    input_text = sys.stdin.read()
    try:
        input_data = json.loads(input_text)
        return input_text, input_data
    except:
        return None, None

def should_process(input_data):
    """Check if we should process this event."""
    if not input_data:
        return False
        
    hook_event = input_data.get('hook_event_name', '')
    if hook_event != 'PostToolUse':
        return False
    
    tool_name = input_data.get('tool_name', '')
    if tool_name not in ['Write', 'Edit', 'MultiEdit']:
        return False
    
    tool_input = input_data.get('tool_input', {})
    file_path = tool_input.get('file_path', '')
    if not file_path or file_path == 'null':
        return False
        
    return True

def run_validator(input_text):
    """Run the quality validator."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    validator_path = os.path.join(script_dir, 'portable-quality-validator.py')
    
    try:
        result = subprocess.run(
            ['python3', validator_path],
            input=input_text,
            capture_output=True,
            text=True
        )
        return result.stdout
    except:
        return None

def main():
    """Main entry point."""
    input_text, input_data = parse_input()
    
    if not should_process(input_data):
        print_continue()
        return
    
    validator_output = run_validator(input_text)
    
    if validator_output:
        print(validator_output.strip())
    else:
        print_continue()

if __name__ == '__main__':
    main()