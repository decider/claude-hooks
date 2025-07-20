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
            return {"decision": "block", "reason": result.stderr.strip()}
        
        if result.stdout:
            return json.loads(result.stdout.strip())
        return {}  # No decision means continue
    except:
        return {}  # No decision means continue

def parse_input():
    """Parse input from stdin."""
    try:
        return json.loads(sys.stdin.read())
    except:
        return None

def run_all_stop_hooks(input_data):
    """Run all stop hooks and collect responses."""
    responses = []
    
    # 1. Run quality validator for final checks
    responses.append(run_hook('stop-hook.py', input_data))
    
    # 2. Send completion notification
    responses.append(run_hook('task-completion-notify.py', input_data))
    
    return responses

def check_for_blocks(responses):
    """Check if any hook wants to block."""
    for response in responses:
        if response.get('decision') == 'block':
            return response
    return None

def main():
    """Main dispatcher entry point."""
    input_data = parse_input()
    if not input_data:
        print(json.dumps({"action": "continue"}))
        return
    
    responses = run_all_stop_hooks(input_data)
    block_response = check_for_blocks(responses)
    
    if block_response:
        print(json.dumps(block_response))

if __name__ == '__main__':
    main()