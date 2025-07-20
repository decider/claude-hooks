#!/usr/bin/env python3
"""
Claude Hooks CLI - Introspection and management tool.

Usage:
    claude-hooks list              Show all hooks in the repository
    claude-hooks explain <file>    Show effective hooks for a specific file
    claude-hooks validate          Validate all configuration files
"""

import json
import os
import sys
from pathlib import Path
from typing import List, Dict, Any

from config_loader import HierarchicalConfigLoader
from cli_utils import Colors, format_hook_info, print_error, print_warning
from hook_validator import find_all_config_files
from cli_parser import create_parser
from cli_commands import cmd_validate
from cli_display import display_hooks_table, display_effective_hooks
from cli_display import display_config_chain


def gather_all_hooks(loader: HierarchicalConfigLoader) -> List[Dict[str, Any]]:
    """Gather all hooks from all configuration files."""
    root = Path(loader.project_root)
    config_files = find_all_config_files(root)
    
    all_hooks = []
    for config_path in config_files:
        hooks = _extract_hooks_from_config(config_path, root)
        all_hooks.extend(hooks)
    
    return all_hooks


def _extract_hooks_from_config(config_path: Path, root: Path) -> List[Dict[str, Any]]:
    """Extract hooks from a single configuration file."""
    hooks = []
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        for event_type in ['pre-tool', 'post-tool', 'stop']:
            event_hooks = config.get('hooks', {}).get(event_type, [])
            for hook in event_hooks:
                hook_info = format_hook_info(hook)
                hook_info['event'] = event_type
                hook_info['defined_in'] = str(config_path.relative_to(root))
                hooks.append(hook_info)
                
    except (json.JSONDecodeError, Exception) as e:
        print_error(f"Reading {config_path}: {e}")
    
    return hooks


def cmd_list(args):
    """List all hooks in the repository."""
    loader = HierarchicalConfigLoader()
    hooks = gather_all_hooks(loader)
    
    if args.json:
        print(json.dumps(hooks, indent=2))
        return
    
    display_hooks_table(hooks, loader.project_root, args.verbose)


def cmd_explain(args):
    """Explain which hooks apply to a specific file."""
    loader = HierarchicalConfigLoader()
    file_path = _resolve_file_path(args.file, loader.project_root)
    
    if not os.path.exists(file_path):
        print_warning(f"File {file_path} does not exist")
    
    rel_path = os.path.relpath(file_path, loader.project_root)
    print(f"\n{Colors.BOLD}Effective hooks for: "
          f"{Colors.CYAN}{rel_path}{Colors.ENDC}\n")
    
    display_effective_hooks(loader, file_path, args.verbose)
    
    if args.verbose:
        display_config_chain(loader, file_path)


def _resolve_file_path(file_path: str, project_root: str) -> str:
    """Resolve file path to absolute."""
    if os.path.isabs(file_path):
        return file_path
    return os.path.join(project_root, file_path)


def main():
    """Main entry point."""
    # Disable colors if output is not a TTY
    if not sys.stdout.isatty():
        Colors.disable()
    
    parser = create_parser()
    args = parser.parse_args()
    
    # Execute command
    if args.command == 'list':
        cmd_list(args)
    elif args.command == 'explain':
        cmd_explain(args)
    elif args.command == 'validate':
        sys.exit(cmd_validate(args))


if __name__ == '__main__':
    main()