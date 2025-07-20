#!/usr/bin/env python3
"""
Claude Hooks CLI - Introspection and management tool.

Usage:
    claude-hooks list              Show all hooks in the repository
    claude-hooks explain <file>    Show effective hooks for a specific file
    claude-hooks validate          Validate all configuration files
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import List, Dict, Any
import fnmatch

from config_loader import HierarchicalConfigLoader
from cli_utils import (Colors, format_hook_info, print_hook_status, 
                      print_error, print_warning, print_success,
                      format_patterns, format_tools)
from hook_validator import validate_config_file, find_all_config_files


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
    
    _display_hooks_table(hooks, loader.project_root, args.verbose)


def _display_hooks_table(hooks: List[Dict[str, Any]], project_root: str, verbose: bool):
    """Display hooks in a formatted table."""
    # Group by event type
    by_event = _group_hooks_by_event(hooks)
    
    print(f"\n{Colors.BOLD}Claude Hooks in {project_root}{Colors.ENDC}\n")
    
    for event in ['pre-tool', 'post-tool', 'stop']:
        if event not in by_event:
            continue
        
        print(f"{Colors.HEADER}[{event}]{Colors.ENDC}")
        _display_event_hooks(by_event[event], verbose)
        print()


def _group_hooks_by_event(hooks: List[Dict[str, Any]]) -> Dict[str, List[Dict]]:
    """Group hooks by event type and sort by priority."""
    by_event = {}
    
    for hook in hooks:
        event = hook['event']
        if event not in by_event:
            by_event[event] = []
        by_event[event].append(hook)
    
    # Sort by priority
    for event in by_event:
        by_event[event].sort(key=lambda h: (-h['priority'], h['id']))
    
    return by_event


def _display_event_hooks(hooks: List[Dict[str, Any]], verbose: bool):
    """Display hooks for a single event type."""
    for hook in hooks:
        status = print_hook_status(hook)
        
        print(f"  {status} {Colors.CYAN}{hook['id']:<25}{Colors.ENDC} "
              f"priority={hook['priority']:<3} "
              f"script={Colors.BLUE}{hook['script']:<30}{Colors.ENDC} "
              f"from {hook['defined_in']}")
        
        if hook['description']:
            print(f"      {hook['description']}")
        
        if verbose:
            _display_hook_details(hook)


def _display_hook_details(hook: Dict[str, Any]):
    """Display verbose hook details."""
    patterns = format_patterns(hook['file_patterns'])
    tools = format_tools(hook['tools'])
    
    print(f"      patterns: {patterns}")
    print(f"      tools: {tools}")
    
    if hook['directories']:
        print(f"      directories: {', '.join(hook['directories'])}")


def cmd_explain(args):
    """Explain which hooks apply to a specific file."""
    loader = HierarchicalConfigLoader()
    file_path = _resolve_file_path(args.file, loader.project_root)
    
    if not os.path.exists(file_path):
        print_warning(f"File {file_path} does not exist")
    
    rel_path = os.path.relpath(file_path, loader.project_root)
    print(f"\n{Colors.BOLD}Effective hooks for: "
          f"{Colors.CYAN}{rel_path}{Colors.ENDC}\n")
    
    _display_effective_hooks(loader, file_path, args.verbose)
    
    if args.verbose:
        _display_config_chain(loader, file_path)


def _resolve_file_path(file_path: str, project_root: str) -> str:
    """Resolve file path to absolute."""
    if os.path.isabs(file_path):
        return file_path
    return os.path.join(project_root, file_path)


def _display_effective_hooks(loader: HierarchicalConfigLoader, file_path: str, verbose: bool):
    """Display hooks that apply to a file."""
    for event_type in ['pre-tool', 'post-tool', 'stop']:
        hooks = loader.get_hooks_for_file(file_path, event_type)
        
        if not hooks:
            continue
        
        print(f"{Colors.HEADER}[{event_type}]{Colors.ENDC}")
        
        for hook in hooks:
            _display_single_hook(hook, verbose)
        
        print()


def _display_single_hook(hook: Dict[str, Any], verbose: bool):
    """Display a single hook with its details."""
    priority = hook.get('priority', 50)
    script = hook.get('script', 'unknown')
    
    print(f"  • {Colors.CYAN}{hook['id']}{Colors.ENDC} "
          f"(priority {priority})")
    print(f"    script: {Colors.BLUE}{script}{Colors.ENDC}")
    
    if hook.get('description'):
        print(f"    {hook['description']}")
    
    if verbose:
        _display_verbose_hook_info(hook)


def _display_verbose_hook_info(hook: Dict[str, Any]):
    """Display verbose information for a hook."""
    if hook.get('config'):
        config_str = json.dumps(hook.get('config', {}))
        print(f"    config: {config_str}")
    
    if 'file_patterns' in hook:
        _display_matched_patterns(hook['file_patterns'])
    
    if 'tools' in hook:
        print(f"    tools: {', '.join(hook['tools'])}")


def _display_matched_patterns(patterns: List[str]):
    """Display which pattern matched (in verbose mode)."""
    # This would need the actual file path to check matches
    # For now, just show the patterns
    print(f"    patterns: {', '.join(patterns)}")


def _display_config_chain(loader: HierarchicalConfigLoader, file_path: str):
    """Display configuration inheritance chain."""
    print(f"{Colors.HEADER}Configuration chain:{Colors.ENDC}")
    
    # Use private method to get config files
    config_files = loader._find_config_files(file_path)
    
    for i, config_file in enumerate(config_files):
        rel_path = os.path.relpath(config_file, loader.project_root)
        print(f"  {i+1}. {rel_path}")
    print()


def cmd_validate(args):
    """Validate all configuration files."""
    loader = HierarchicalConfigLoader()
    root = Path(loader.project_root)
    config_files = find_all_config_files(root)
    
    if not config_files:
        print_warning("No configuration files found")
        return 1
    
    print(f"\n{Colors.BOLD}Validating hook configurations...{Colors.ENDC}\n")
    
    all_errors = []
    all_warnings = []
    
    for config_path in config_files:
        errors, warnings = validate_config_file(config_path, root)
        
        rel_path = config_path.relative_to(root)
        
        if errors:
            print(f"  {Colors.FAIL}✗{Colors.ENDC} {rel_path}")
            all_errors.extend(errors)
        else:
            print(f"  {Colors.GREEN}✓{Colors.ENDC} {rel_path}")
        
        all_warnings.extend(warnings)
    
    print()
    
    # Report results
    _display_validation_results(all_errors, all_warnings)
    
    return 1 if all_errors else 0


def _display_validation_results(errors: List[str], warnings: List[str]):
    """Display validation results."""
    if errors:
        print(f"{Colors.FAIL}Errors found:{Colors.ENDC}")
        for error in errors:
            print(f"  • {error}")
        print()
    
    if warnings:
        print(f"{Colors.WARNING}Warnings:{Colors.ENDC}")
        for warning in warnings:
            print(f"  • {warning}")
        print()
    
    if not errors and not warnings:
        print_success("All configurations are valid!")


def main():
    """Main entry point."""
    # Disable colors if output is not a TTY
    if not sys.stdout.isatty():
        Colors.disable()
    
    parser = _create_parser()
    args = parser.parse_args()
    
    # Execute command
    if args.command == 'list':
        cmd_list(args)
    elif args.command == 'explain':
        cmd_explain(args)
    elif args.command == 'validate':
        sys.exit(cmd_validate(args))


def _create_parser():
    """Create the argument parser."""
    parser = argparse.ArgumentParser(
        description='Claude Hooks CLI - Introspection and management tool',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    subparsers = parser.add_subparsers(dest='command', required=True)
    
    # List command
    list_parser = subparsers.add_parser(
        'list', 
        help='List all hooks in the repository'
    )
    list_parser.add_argument(
        '--json', 
        action='store_true', 
        help='Output as JSON'
    )
    list_parser.add_argument(
        '-v', '--verbose', 
        action='store_true', 
        help='Show detailed information'
    )
    
    # Explain command
    explain_parser = subparsers.add_parser(
        'explain', 
        help='Show effective hooks for a file'
    )
    explain_parser.add_argument('file', help='File path to explain')
    explain_parser.add_argument(
        '-v', '--verbose', 
        action='store_true', 
        help='Show detailed information'
    )
    
    # Validate command
    validate_parser = subparsers.add_parser(
        'validate', 
        help='Validate all configuration files'
    )
    
    return parser


if __name__ == '__main__':
    main()