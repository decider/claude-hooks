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

def main():
    """Main dispatcher entry point."""
    # Read input from stdin
    try:
        input_data = json.loads(sys.stdin.read())
    except:
        print(json.dumps({"action": "continue"}))
        return
    
    # Get tool name
    tool_name = input_data.get('tool_name', '')
    
    # Route based on tool type
    if tool_name in ['Write', 'Edit', 'MultiEdit']:
        # Run quality validation on written files
        response = run_hook('post-tool-hook.py', input_data)
    else:
        # No post-processing for other tools yet
        response = {"action": "continue"}
    
    # Could add more hooks here in the future:
    # - Git commit hooks
    # - Test completion hooks
    # - Build completion hooks
    # etc.
    
    # Output response
    print(json.dumps(response))

if __name__ == '__main__':
    main()