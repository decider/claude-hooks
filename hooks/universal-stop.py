#!/usr/bin/env python3
"""Universal Stop dispatcher using hierarchical config."""

import sys
import json
import os
import subprocess
from config_loader import ROOT, _read_yaml

def run_hook(hook, ctx):
    """Run a single hook script with config passed via env."""
    script_path = hook["script"]
    
    # Handle relative paths
    if not os.path.isabs(script_path):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        script_path = os.path.join(script_dir, "..", script_path)
    
    if not os.path.exists(script_path):
        return {}
    
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
            return {"decision": "block", "reason": result.stderr.strip()}
        
        if result.stdout:
            return json.loads(result.stdout.strip())
        
        return {}
    except Exception as e:
        # On error, continue
        return {}

def get_stop_hooks():
    """Get all stop hooks from root config only."""
    # Stop hooks are global, not file-specific
    root_cfg = _read_yaml(os.path.join(ROOT, ".claude", "hooks.yaml"))
    hooks = root_cfg.get("stop", [])
    
    # Sort by priority (highest first)
    return sorted(hooks, key=lambda h: h.get("priority", 0), reverse=True)

def main():
    """Main dispatcher entry point."""
    # Read input from stdin
    try:
        ctx = json.loads(sys.stdin.read())
    except:
        # No output for stop hooks by default
        return
    
    # Get all stop hooks
    hooks = get_stop_hooks()
    
    # Run hooks in priority order
    responses = []
    for hook in hooks:
        result = run_hook(hook, ctx)
        if result:
            responses.append(result)
    
    # Check if any hook wants to block
    for response in responses:
        if response.get("decision") == "block":
            print(json.dumps(response))
            return
    
    # No blocking response, output nothing

if __name__ == "__main__":
    main()