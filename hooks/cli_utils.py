#!/usr/bin/env python3
"""Utilities for the Claude Hooks CLI."""

import sys
from typing import Dict, Any, List


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


def format_hook_info(hook: Dict[str, Any]) -> Dict[str, Any]:
    """Format hook information for display."""
    return {
        'id': hook.get('id', 'unnamed'),
        'event': hook.get('event', 'unknown'),
        'script': hook.get('script', 'unknown'),
        'priority': hook.get('priority', 50),
        'file_patterns': hook.get('file_patterns', ['*']),
        'tools': hook.get('tools', ['*']),
        'directories': hook.get('directories', []),
        'disabled': hook.get('disabled', False),
        'description': hook.get('description', ''),
        'defined_in': hook.get('defined_in', 'unknown'),
    }


def print_hook_status(hook: Dict[str, Any]) -> str:
    """Get status indicator for a hook."""
    if hook['disabled']:
        return f"{Colors.FAIL}(disabled){Colors.ENDC}"
    return f"{Colors.GREEN}✓{Colors.ENDC}"


def print_error(message: str):
    """Print an error message."""
    print(f"{Colors.FAIL}Error: {message}{Colors.ENDC}", file=sys.stderr)


def print_warning(message: str):
    """Print a warning message."""
    print(f"{Colors.WARNING}Warning: {message}{Colors.ENDC}", file=sys.stderr)


def print_success(message: str):
    """Print a success message."""
    print(f"{Colors.GREEN}{message}{Colors.ENDC}")


def format_patterns(patterns: List[str]) -> str:
    """Format file patterns for display."""
    if patterns == ['*']:
        return 'all files'
    return ', '.join(patterns)


def format_tools(tools: List[str]) -> str:
    """Format tools for display."""
    if tools == ['*']:
        return 'all tools'
    return ', '.join(tools)