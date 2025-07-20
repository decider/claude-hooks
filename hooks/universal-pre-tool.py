#!/usr/bin/env python3
"""Universal PreToolUse dispatcher using hierarchical config."""

import sys
import json
import os
import subprocess
from config_loader import get_hooks_for_phase

def run_hook(hook, ctx):
    """Run a single hook script with config passed via env."""
    script_path = hook["script"]
    
    # Handle relative paths
    if not os.path.isabs(script_path):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        script_path = os.path.join(script_dir, "..", script_path)
    
    if not os.path.exists(script_path):
        return {"action": "continue"}
    
    # Set up environment with hook config
    env = os.environ.copy()
    env["CLAUDE_HOOK_CONFIG"] = json.dumps(hook.get("config", {}))
    
    try:
        result = subprocess.run(
            ["python3", script_path],
            input=json.dumps(ctx).encode(),
            env=env,
            capture_output=True,
            text=True,
        )
        
        # Handle different return codes
        if result.returncode == 2:
            # Legacy support: exit code 2 means block
            return {"action": "block", "message": result.stderr.strip()}
        
        if result.stdout:
            return json.loads(result.stdout.strip())
        
        return {"action": "continue"}
    except Exception as e:
        # On error, continue rather than block
        return {"action": "continue"}

def main():
    """Main dispatcher entry point."""
    # Read input from stdin
    try:
        ctx = json.loads(sys.stdin.read())
    except:
        print(json.dumps({"action": "continue"}))
        return
    
    # Get file path from tool input
    tool_input = ctx.get("tool_input", {})
    file_path = tool_input.get("file_path")
    
    if not file_path:
        # No file path, no hooks to run
        print(json.dumps({"action": "continue"}))
        return
    
    # Get all pre-tool hooks for this file
    hooks = get_hooks_for_phase(file_path, "pre-tool")
    
    # Run hooks in priority order
    for hook in hooks:
        result = run_hook(hook, ctx)
        
        # If any hook blocks, stop and return block
        if result.get("action") == "block":
            print(json.dumps(result))
            return
    
    # All hooks passed
    print(json.dumps({"action": "continue"}))

if __name__ == "__main__":
    main()