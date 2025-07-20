#!/usr/bin/env python3
"""Universal PostToolUse dispatcher using hierarchical config."""

import sys
import json
import os
import subprocess
from config_loader import get_hooks_for_phase

def run_hook(hook, ctx):
    """Run a single hook script with config passed via env."""
    # Skip hooks without script field (built-ins)
    if "script" not in hook:
        return None
    
    script_path = hook["script"]
    
    # Handle relative paths
    if not os.path.isabs(script_path):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        script_path = os.path.join(script_dir, "..", script_path)
    
    if not os.path.exists(script_path):
        return None
    
    # Set up environment with hook config
    env = os.environ.copy()
    env["CLAUDE_HOOK_CONFIG"] = json.dumps(hook.get("config", {}))
    
    try:
        result = subprocess.run(
            ["python3", script_path],
            input=json.dumps(ctx),
            env=env,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        # Handle official Claude Code hook exit codes
        if result.returncode == 2:
            # Exit code 2 means block - stderr goes to Claude
            print(result.stderr.strip(), file=sys.stderr)
            sys.exit(2)
        elif result.returncode != 0:
            # Other non-zero exit codes are non-blocking errors - stderr shown to user
            print(result.stderr.strip(), file=sys.stderr)
            sys.exit(result.returncode)
        
        # Exit code 0 - pass through stdout (including JSON)
        if result.stdout.strip():
            print(result.stdout.strip())
            sys.exit(0)
        
        return None
    except Exception as e:
        # On error, continue rather than block
        return None

def main():
    """Main dispatcher entry point."""
    
    # Read input from stdin
    try:
        ctx = json.loads(sys.stdin.read())
    except:
        sys.exit(0)
    
    # Get file path from tool input
    tool_input = ctx.get("tool_input", {})
    file_path = tool_input.get("file_path")
    
    if not file_path:
        # No file path, no hooks to run
        sys.exit(0)
    
    # Get all post-tool hooks for this file
    hooks = get_hooks_for_phase(file_path, "post-tool")
    
    # Run hooks in priority order
    for hook in hooks:
        run_hook(hook, ctx)
        # run_hook will exit directly if blocking, so if we get here it's continue
    
    # All hooks passed
    sys.exit(0)

if __name__ == "__main__":
    main()