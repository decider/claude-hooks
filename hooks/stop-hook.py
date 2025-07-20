#!/usr/bin/env python3
"""Direct Stop Hook Handler - Processes Stop events and runs code quality checks."""

import json
import sys
import subprocess
import os

def parse_input():
    """Parse input from stdin."""
    input_text = sys.stdin.read()
    try:
        input_data = json.loads(input_text)
        return input_text, input_data
    except:
        return None, None

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
    if not input_data:
        return
    
    # Only process Stop events
    event_type = input_data.get('hook_event_name', '')
    if event_type != 'Stop':
        return
    
    # Run validator and print output if any
    validator_output = run_validator(input_text)
    if validator_output:
        print(validator_output.strip())

if __name__ == '__main__':
    main()