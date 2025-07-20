#!/usr/bin/env python3
"""Direct PostToolUse Hook Handler - Processes PostToolUse events for Write/Edit/MultiEdit operations."""

import json
import sys
import subprocess
import os

def main():
    """Main entry point."""
    # Read input from stdin
    input_text = sys.stdin.read()
    
    try:
        input_data = json.loads(input_text)
    except:
        # Invalid JSON, continue
        print(json.dumps({"action": "continue"}))
        return
    
    # Only process PostToolUse events
    hook_event = input_data.get('hook_event_name', '')
    if hook_event != 'PostToolUse':
        print(json.dumps({"action": "continue"}))
        return
    
    # Only process Write/Edit/MultiEdit tools
    tool_name = input_data.get('tool_name', '')
    if tool_name not in ['Write', 'Edit', 'MultiEdit']:
        print(json.dumps({"action": "continue"}))
        return
    
    # Check if file path exists
    tool_input = input_data.get('tool_input', {})
    file_path = tool_input.get('file_path', '')
    
    if not file_path or file_path == 'null':
        print(json.dumps({"action": "continue"}))
        return
    
    # Forward to the quality validator
    script_dir = os.path.dirname(os.path.abspath(__file__))
    validator_path = os.path.join(script_dir, 'portable-quality-validator.py')
    
    try:
        # Run the validator with the same input
        result = subprocess.run(
            ['python3', validator_path],
            input=input_text,
            capture_output=True,
            text=True
        )
        
        # Pass through the validator's output
        if result.stdout:
            print(result.stdout.strip())
        else:
            print(json.dumps({"action": "continue"}))
            
    except Exception as e:
        # If validator fails, continue
        print(json.dumps({"action": "continue"}))

if __name__ == '__main__':
    main()