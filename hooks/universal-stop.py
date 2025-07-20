#!/usr/bin/env python3
"""Universal Stop dispatcher using hierarchical config."""

import sys
import json
import os
import subprocess
from config_loader import ROOT, _read_json

def _get_script_path(hook):
    """Get absolute script path from hook config."""
    if "script" not in hook:
        return None
    
    script_path = hook["script"]
    if not os.path.isabs(script_path):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        script_path = os.path.join(script_dir, "..", script_path)
    
    return script_path if os.path.exists(script_path) else None

def _handle_hook_result(result):
    """Process hook subprocess result and return action."""
    if result.returncode == 2:
        # Exit code 2 means block - stderr goes to Claude
        return {"decision": "block", "reason": result.stderr.strip()}
    elif result.returncode != 0:
        # Other non-zero exit codes are non-blocking errors
        print(result.stderr.strip(), file=sys.stderr)
        return None
    
    # Exit code 0 - check for JSON output
    if result.stdout.strip():
        try:
            return json.loads(result.stdout.strip())
        except json.JSONDecodeError:
            # Not JSON, but successful - print to stdout
            print(result.stdout.strip())
    
    return None

def run_hook(hook, ctx):
    """Run a single hook script with config passed via env."""
    script_path = _get_script_path(hook)
    if not script_path:
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
        return _handle_hook_result(result)
    except Exception:
        # On error, continue
        return None

def get_stop_hooks():
    """Get all stop hooks from root config only."""
    # Stop hooks are global, not file-specific
    root_cfg = _read_json(os.path.join(ROOT, ".claude", "hooks.json"))
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
        sys.exit(0)
    
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
            reason = response.get("reason", "Hook blocked stop")
            print(reason, file=sys.stderr)
            sys.exit(2)
    
    # No blocking response, exit successfully
    sys.exit(0)

if __name__ == "__main__":
    main()