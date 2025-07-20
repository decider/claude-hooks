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
        # Invalid JSON, no output means continue
        return
    
    # Only process Stop events
    event_type = input_data.get('hook_event_name', '')
    if event_type != 'Stop':
        # No output means continue
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
        # Otherwise no output means continue
            
    except Exception as e:
        # If validator fails, no output means continue
        pass

if __name__ == '__main__':
    main()