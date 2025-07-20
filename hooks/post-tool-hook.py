#!/usr/bin/env python3
import json
import sys
import subprocess

def main():
    input_text = sys.stdin.read()
    try:
        input_data = json.loads(input_text)
    except:
        return
    
    if not _should_validate(input_data):
        return
        
    file_path = input_data.get('tool_input', {}).get('file_path', '')
    if not (file_path and file_path.endswith('.py')):
        return
        
    _run_validator(input_text)

def _should_validate(input_data):
    """Check if we should run validation for this tool use."""
    return (input_data.get('hook_event_name') == 'PostToolUse' and 
            input_data.get('tool_name') in ['Write', 'Edit', 'MultiEdit'])

def _run_validator(input_text):
    """Run the quality validator on the input."""
    try:
        result = subprocess.run(
            ['python3', 'portable-quality-validator.py'],
            input=input_text,
            capture_output=True,
            text=True
        )
        if result.stdout:
            print(result.stdout.strip())
    except:
        pass

if __name__ == '__main__':
    main()