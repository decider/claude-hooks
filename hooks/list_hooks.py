#!/usr/bin/env python3
"""
CLI tool for hook introspection.
claude-hooks list      -> dump every hook in repo
claude-hooks explain F -> show effective hooks for file F
"""

import argparse
import json
import os
import textwrap
from pathlib import Path
from config_loader import effective_config, _collect_configs, ROOT
import fnmatch
import sys

def all_config_files():
    """Find all config files in the project."""
    configs = []
    
    # Find all .claude-hooks.json files
    for path in Path(ROOT).rglob(".claude-hooks.json"):
        configs.append(path)
    
    # Add root config if it exists
    root_cfg = Path(ROOT) / ".claude" / "hooks.json"
    if root_cfg.exists():
        configs.append(root_cfg)
    
    return configs

def create_hook_entry(hook, phase, cfg_path):
    """Create a single hook entry."""
    return {
        "id": hook["id"],
        "event": phase,
        "file_patterns": hook.get("file_patterns", ["*"]),
        "priority": hook.get("priority", 0),
        "defined_in": str(cfg_path.relative_to(ROOT)),
        "script": hook.get("script", ""),
        "disabled": hook.get("disable", False),
    }

def extract_hooks_from_config(cfg, cfg_path):
    """Extract all hooks from a configuration file."""
    hooks = []
    for phase in ("pre-tool", "post-tool", "stop"):
        for hook in cfg.get(phase, []):
            hooks.append(create_hook_entry(hook, phase, cfg_path))
    return hooks

def gather_all_hooks():
    """Gather all hooks from all config files."""
    hooks = []
    
    for cfg_path in all_config_files():
        try:
            cfg = json.loads(cfg_path.read_text()) or {}
        except:
            continue
        
        hooks.extend(extract_hooks_from_config(cfg, cfg_path))
    
    return hooks

def cmd_list(args):
    """List all hooks in the repository."""
    hooks = gather_all_hooks()
    
    if args.json:
        print(json.dumps(hooks, indent=2))
        return
    
    # Sort hooks for display
    hooks.sort(key=lambda h: (h["event"], -h["priority"], h["id"]))
    
    if not hooks:
        print("No hooks found. Create .claude/hooks.yaml to get started.")
        return
    
    # Display as table
    print(f"{'EVENT':12} {'PRIO':4} {'ID':25} {'SCRIPT':35} {'FROM'}")
    print("-" * 95)
    
    for h in hooks:
        flag = " (disabled)" if h["disabled"] else ""
        event = h['event'][:12]
        priority = str(h['priority'])[:4]
        hook_id = h['id'][:25]
        script = h['script'][:35] if h['script'] else "N/A"
        defined_in = h['defined_in']
        
        print(f"{event:12} {priority:4} {hook_id:25} {script:35} {defined_in}{flag}")

def validate_file_path(path):
    """Validate that the file path exists."""
    abs_path = str((Path(ROOT) / path).resolve())
    if not os.path.exists(abs_path):
        print(f"Error: File not found: {path}")
        return None
    return abs_path

def print_hook_details(hook):
    """Print detailed information for a single hook."""
    patterns = ", ".join(hook.get("file_patterns", ["*"]))
    config = hook.get("config", {})
    config_str = json.dumps(config) if config else "{}"
    
    print(f"  • {hook['id']}")
    print(f"    priority: {hook.get('priority', 0)}")
    print(f"    patterns: {patterns}")
    print(f"    script:   {hook.get('script', 'N/A')}")
    if config:
        print(f"    config:   {config_str}")

def print_phase_hooks(cfg):
    """Print hooks organized by phase."""
    has_hooks = False
    for phase in ("pre-tool", "post-tool", "stop"):
        phase_hooks = cfg.get(phase, [])
        if not phase_hooks:
            continue
        
        has_hooks = True
        print(f"[{phase}]")
        
        # Sort by priority
        for hook in sorted(phase_hooks, key=lambda h: -h.get("priority", 0)):
            print_hook_details(hook)
        print()
    
    if not has_hooks:
        print("No hooks configured for this file.")

def cmd_explain(args):
    """Explain effective hooks for a specific file."""
    abs_path = validate_file_path(args.file)
    if not abs_path:
        return 1
    
    cfg = effective_config(abs_path)
    
    if args.json:
        print(json.dumps(cfg, indent=2))
        return
    
    print(f"\nEffective hooks for {args.file}:\n")
    print_phase_hooks(cfg)

def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        prog="claude-hooks",
        description="Introspection tool for Claude Code hooks"
    )
    
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # List command
    list_parser = subparsers.add_parser("list", help="List all hooks in the repository")
    list_parser.add_argument("--json", action="store_true", help="Output as JSON")
    
    # Explain command
    explain_parser = subparsers.add_parser("explain", help="Show effective hooks for a file")
    explain_parser.add_argument("file", help="File path to explain hooks for")
    explain_parser.add_argument("--json", action="store_true", help="Output as JSON")
    
    args = parser.parse_args()
    
    if args.command == "list":
        cmd_list(args)
    elif args.command == "explain":
        return cmd_explain(args)

if __name__ == "__main__":
    sys.exit(main() or 0)