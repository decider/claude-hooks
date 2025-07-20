#!/usr/bin/env python3
"""Direct Stop Hook Handler - Processes Stop events and runs code quality checks."""

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
    
    # Only process Stop events
    event_type = input_data.get('hook_event_name', '')
    if event_type != 'Stop':
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
        
        # If exit code 2, that means block
        if result.returncode == 2:
            print(result.stderr.strip(), file=sys.stderr)
            sys.exit(2)  # Block with same exit code
        
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