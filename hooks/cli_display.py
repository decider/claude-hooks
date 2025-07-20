#!/usr/bin/env python3
"""Display functions for Claude Hooks CLI."""

import json
import os
from typing import List, Dict, Any

from config_loader import HierarchicalConfigLoader
from cli_utils import Colors, print_warning, print_hook_status
from cli_utils import format_patterns, format_tools


def display_hooks_table(hooks: List[Dict[str, Any]], project_root: str, verbose: bool):
    """Display hooks in a formatted table."""
    # Group by event type
    by_event = group_hooks_by_event(hooks)
    
    print(f"\n{Colors.BOLD}Claude Hooks in {project_root}{Colors.ENDC}\n")
    
    for event in ['pre-tool', 'post-tool', 'stop']:
        if event not in by_event:
            continue
        
        print(f"{Colors.HEADER}[{event}]{Colors.ENDC}")
        display_event_hooks(by_event[event], verbose)
        print()


def group_hooks_by_event(hooks: List[Dict[str, Any]]) -> Dict[str, List[Dict]]:
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


def display_event_hooks(hooks: List[Dict[str, Any]], verbose: bool):
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
            display_hook_details(hook)


def display_hook_details(hook: Dict[str, Any]):
    """Display verbose hook details."""
    patterns = format_patterns(hook['file_patterns'])
    tools = format_tools(hook['tools'])
    
    print(f"      patterns: {patterns}")
    print(f"      tools: {tools}")
    
    if hook['directories']:
        print(f"      directories: {', '.join(hook['directories'])}")


def display_effective_hooks(loader: HierarchicalConfigLoader, file_path: str, verbose: bool):
    """Display hooks that apply to a file."""
    for event_type in ['pre-tool', 'post-tool', 'stop']:
        hooks = loader.get_hooks_for_file(file_path, event_type)
        
        if not hooks:
            continue
        
        print(f"{Colors.HEADER}[{event_type}]{Colors.ENDC}")
        
        for hook in hooks:
            display_single_hook(hook, verbose)
        
        print()


def display_single_hook(hook: Dict[str, Any], verbose: bool):
    """Display a single hook with its details."""
    priority = hook.get('priority', 50)
    script = hook.get('script', 'unknown')
    
    print(f"  • {Colors.CYAN}{hook['id']}{Colors.ENDC} "
          f"(priority {priority})")
    print(f"    script: {Colors.BLUE}{script}{Colors.ENDC}")
    
    if hook.get('description'):
        print(f"    {hook['description']}")
    
    if verbose:
        display_verbose_hook_info(hook)


def display_verbose_hook_info(hook: Dict[str, Any]):
    """Display verbose information for a hook."""
    if hook.get('config'):
        config_str = json.dumps(hook.get('config', {}))
        print(f"    config: {config_str}")
    
    if 'file_patterns' in hook:
        display_matched_patterns(hook['file_patterns'])
    
    if 'tools' in hook:
        print(f"    tools: {', '.join(hook['tools'])}")


def display_matched_patterns(patterns: List[str]):
    """Display which pattern matched (in verbose mode)."""
    # This would need the actual file path to check matches
    # For now, just show the patterns
    print(f"    patterns: {', '.join(patterns)}")


def display_config_chain(loader: HierarchicalConfigLoader, file_path: str):
    """Display configuration inheritance chain."""
    print(f"{Colors.HEADER}Configuration chain:{Colors.ENDC}")
    
    # Use private method to get config files
    config_files = loader._find_config_files(file_path)
    
    for i, config_file in enumerate(config_files):
        rel_path = os.path.relpath(config_file, loader.project_root)
        print(f"  {i+1}. {rel_path}")
    print()