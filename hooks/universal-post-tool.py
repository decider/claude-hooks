#!/usr/bin/env python3
"""Universal PostToolUse dispatcher - routes to appropriate hooks based on tool type."""

import json
import sys
import subprocess
import os

def run_hook(hook_script, input_data):
    """Run a hook script and return its response."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    hook_path = os.path.join(script_dir, hook_script)
    
    if not os.path.exists(hook_path):
        return {"action": "continue"}
    
    try:
        result = subprocess.run(
            ['python3', hook_path],
            input=json.dumps(input_data),
            capture_output=True,
            text=True
        )
        
        # If exit code 2, that means block
        if result.returncode == 2:
            return {"action": "block", "message": result.stderr.strip()}
        
        if result.stdout:
            return json.loads(result.stdout.strip())
        return {"action": "continue"}
    except:
        return {"action": "continue"}

def parse_input():
    """Parse input from stdin."""
    try:
        return json.loads(sys.stdin.read())
    except:
        return None

def route_to_hook(input_data):
    """Route to appropriate hook based on tool type."""
    tool_name = input_data.get('tool_name', '')
    
    if tool_name in ['Write', 'Edit', 'MultiEdit']:
        # Run quality validation on written files
        return run_hook('post-tool-hook.py', input_data)
    
    # No post-processing for other tools yet
    return {"action": "continue"}

def main():
    """Main dispatcher entry point."""
    input_data = parse_input()
    if not input_data:
        print(json.dumps({"action": "continue"}))
        return
    
    response = route_to_hook(input_data)
    print(json.dumps(response))

if __name__ == '__main__':
    main()