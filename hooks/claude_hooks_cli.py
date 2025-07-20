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


class Colors:
    """Terminal colors for pretty output."""
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    
    @staticmethod
    def disable():
        """Disable colors for non-TTY output."""
        Colors.HEADER = ''
        Colors.BLUE = ''
        Colors.CYAN = ''
        Colors.GREEN = ''
        Colors.WARNING = ''
        Colors.FAIL = ''
        Colors.ENDC = ''
        Colors.BOLD = ''
        Colors.UNDERLINE = ''


def find_all_config_files(root: Path) -> List[Path]:
    """Find all hook configuration files in the project."""
    configs = []
    
    # Check for root config
    root_config = root / '.claude' / 'hookconfig.json'
    if root_config.exists():
        configs.append(root_config)
    
    # Find all .claude-hooks.json files
    for config_path in root.rglob('.claude-hooks.json'):
        configs.append(config_path)
    
    return sorted(configs)


def gather_all_hooks(loader: HierarchicalConfigLoader) -> List[Dict[str, Any]]:
    """Gather all hooks from all configuration files."""
    root = Path(loader.project_root)
    config_files = find_all_config_files(root)
    
    all_hooks = []
    
    for config_path in config_files:
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
            
            for event_type in ['pre-tool', 'post-tool', 'stop']:
                for hook in config.get('hooks', {}).get(event_type, []):
                    hook_info = {
                        'id': hook.get('id', 'unnamed'),
                        'event': event_type,
                        'script': hook.get('script', 'unknown'),
                        'priority': hook.get('priority', 50),
                        'file_patterns': hook.get('file_patterns', ['*']),
                        'tools': hook.get('tools', ['*']),
                        'directories': hook.get('directories', []),
                        'disabled': hook.get('disabled', False),
                        'description': hook.get('description', ''),
                        'defined_in': str(config_path.relative_to(root)),
                    }
                    all_hooks.append(hook_info)
        except json.JSONDecodeError as e:
            print(f"{Colors.FAIL}Error reading {config_path}: Invalid JSON - {e}{Colors.ENDC}", file=sys.stderr)
        except Exception as e:
            print(f"{Colors.FAIL}Error reading {config_path}: {e}{Colors.ENDC}", file=sys.stderr)
    
    return all_hooks


def cmd_list(args):
    """List all hooks in the repository."""
    loader = HierarchicalConfigLoader()
    hooks = gather_all_hooks(loader)
    
    if args.json:
        # JSON output for tooling
        print(json.dumps(hooks, indent=2))
        return
    
    # Group hooks by event type
    by_event = {}
    for hook in hooks:
        event = hook['event']
        if event not in by_event:
            by_event[event] = []
        by_event[event].append(hook)
    
    # Sort hooks within each event by priority
    for event in by_event:
        by_event[event].sort(key=lambda h: (-h['priority'], h['id']))
    
    # Display hooks
    print(f"\n{Colors.BOLD}Claude Hooks in {loader.project_root}{Colors.ENDC}\n")
    
    for event in ['pre-tool', 'post-tool', 'stop']:
        if event not in by_event:
            continue
            
        print(f"{Colors.HEADER}[{event}]{Colors.ENDC}")
        
        for hook in by_event[event]:
            status = f"{Colors.FAIL}(disabled){Colors.ENDC}" if hook['disabled'] else f"{Colors.GREEN}✓{Colors.ENDC}"
            patterns = ', '.join(hook['file_patterns']) if hook['file_patterns'] != ['*'] else 'all files'
            tools = ', '.join(hook['tools']) if hook['tools'] != ['*'] else 'all tools'
            
            print(f"  {status} {Colors.CYAN}{hook['id']:<25}{Colors.ENDC} "
                  f"priority={hook['priority']:<3} "
                  f"script={Colors.BLUE}{hook['script']:<30}{Colors.ENDC} "
                  f"from {hook['defined_in']}")
            
            if hook['description']:
                print(f"      {hook['description']}")
            
            if args.verbose:
                print(f"      patterns: {patterns}")
                print(f"      tools: {tools}")
                if hook['directories']:
                    print(f"      directories: {', '.join(hook['directories'])}")
        
        print()


def cmd_explain(args):
    """Explain which hooks apply to a specific file."""
    loader = HierarchicalConfigLoader()
    file_path = args.file
    
    # Make path absolute if relative
    if not os.path.isabs(file_path):
        file_path = os.path.join(loader.project_root, file_path)
    
    # Check if file exists
    if not os.path.exists(file_path):
        print(f"{Colors.WARNING}Warning: File {file_path} does not exist{Colors.ENDC}", file=sys.stderr)
    
    print(f"\n{Colors.BOLD}Effective hooks for: {Colors.CYAN}{os.path.relpath(file_path, loader.project_root)}{Colors.ENDC}\n")
    
    # Get configuration path
    config = loader.get_config_for_path(file_path)
    
    # Show hooks for each event type
    for event_type in ['pre-tool', 'post-tool', 'stop']:
        hooks = loader.get_hooks_for_file(file_path, event_type)
        
        if not hooks:
            continue
        
        print(f"{Colors.HEADER}[{event_type}]{Colors.ENDC}")
        
        for hook in hooks:
            priority = hook.get('priority', 50)
            script = hook.get('script', 'unknown')
            config_str = json.dumps(hook.get('config', {}))
            
            print(f"  • {Colors.CYAN}{hook['id']}{Colors.ENDC} "
                  f"(priority {priority})")
            print(f"    script: {Colors.BLUE}{script}{Colors.ENDC}")
            
            if hook.get('description'):
                print(f"    {hook['description']}")
            
            if hook.get('config') and args.verbose:
                print(f"    config: {config_str}")
            
            # Show which patterns matched
            if args.verbose:
                if 'file_patterns' in hook:
                    matching_pattern = None
                    for pattern in hook['file_patterns']:
                        if fnmatch.fnmatch(os.path.basename(file_path), pattern):
                            matching_pattern = pattern
                            break
                    if matching_pattern:
                        print(f"    matched pattern: {matching_pattern}")
                
                if 'tools' in hook:
                    print(f"    tools: {', '.join(hook['tools'])}")
        
        print()
    
    # Show config inheritance chain if verbose
    if args.verbose:
        print(f"{Colors.HEADER}Configuration chain:{Colors.ENDC}")
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
        print(f"{Colors.WARNING}No configuration files found{Colors.ENDC}")
        return 1
    
    print(f"\n{Colors.BOLD}Validating hook configurations...{Colors.ENDC}\n")
    
    errors = []
    warnings = []
    
    for config_path in config_files:
        rel_path = config_path.relative_to(root)
        
        try:
            with open(config_path, 'r') as f:
                content = f.read()
                if not content.strip():
                    warnings.append(f"{rel_path}: Empty configuration file")
                    continue
                    
                config = json.loads(content)
            
            # Validate structure
            if 'hooks' in config:
                hooks = config['hooks']
                if not isinstance(hooks, dict):
                    errors.append(f"{rel_path}: 'hooks' must be an object")
                    continue
                
                for event_type in hooks:
                    if event_type not in ['pre-tool', 'post-tool', 'stop']:
                        warnings.append(f"{rel_path}: Unknown event type '{event_type}'")
                    
                    if not isinstance(hooks[event_type], list):
                        errors.append(f"{rel_path}: hooks.{event_type} must be an array")
                        continue
                    
                    for i, hook in enumerate(hooks[event_type]):
                        # Check required fields
                        if 'id' not in hook:
                            errors.append(f"{rel_path}: hooks.{event_type}[{i}] missing required 'id' field")
                        
                        if 'script' not in hook:
                            errors.append(f"{rel_path}: hooks.{event_type}[{i}] missing required 'script' field")
                        
                        # Check script exists
                        if 'script' in hook:
                            script_path = root / 'hooks' / hook['script']
                            if not script_path.exists():
                                warnings.append(f"{rel_path}: Script '{hook['script']}' not found")
            
            print(f"  {Colors.GREEN}✓{Colors.ENDC} {rel_path}")
            
        except json.JSONDecodeError as e:
            errors.append(f"{rel_path}: Invalid JSON - {e}")
            print(f"  {Colors.FAIL}✗{Colors.ENDC} {rel_path} - Invalid JSON")
        except Exception as e:
            errors.append(f"{rel_path}: {e}")
            print(f"  {Colors.FAIL}✗{Colors.ENDC} {rel_path} - Error reading file")
    
    print()
    
    # Report results
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
        print(f"{Colors.GREEN}All configurations are valid!{Colors.ENDC}")
    
    return 1 if errors else 0


def main():
    """Main entry point."""
    # Disable colors if output is not a TTY
    if not sys.stdout.isatty():
        Colors.disable()
    
    parser = argparse.ArgumentParser(
        description='Claude Hooks CLI - Introspection and management tool',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    subparsers = parser.add_subparsers(dest='command', required=True)
    
    # List command
    list_parser = subparsers.add_parser('list', help='List all hooks in the repository')
    list_parser.add_argument('--json', action='store_true', help='Output as JSON')
    list_parser.add_argument('-v', '--verbose', action='store_true', help='Show detailed information')
    
    # Explain command
    explain_parser = subparsers.add_parser('explain', help='Show effective hooks for a file')
    explain_parser.add_argument('file', help='File path to explain')
    explain_parser.add_argument('-v', '--verbose', action='store_true', help='Show detailed information')
    
    # Validate command
    validate_parser = subparsers.add_parser('validate', help='Validate all configuration files')
    
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