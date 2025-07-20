#!/usr/bin/env python3
"""Universal Stop event dispatcher - runs all cleanup/notification hooks."""

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
    
    # Run all stop hooks
    responses = []
    
    # 1. Run quality validator for final checks
    responses.append(run_hook('stop-hook.py', input_data))
    
    # 2. Send completion notification
    responses.append(run_hook('task-completion-notify.py', input_data))
    
    # Could add more hooks here in the future:
    # - Session summary generator
    # - Git status check
    # - Test coverage report
    # etc.
    
    # If any hook wants to block, respect that
    for response in responses:
        if response.get('action') == 'block':
            print(json.dumps(response))
            return
    
    # Otherwise continue
    print(json.dumps({"action": "continue"}))

if __name__ == '__main__':
    main()