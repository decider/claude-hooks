#!/usr/bin/env python3
"""Hook filtering utilities for Claude Hooks."""

import os
import fnmatch
from typing import Dict, List, Any, Optional


def filter_hooks_for_file(hooks: List[Dict[str, Any]], file_path: str,
                         tool: Optional[str], project_root: str) -> List[Dict[str, Any]]:
    """Filter hooks that apply to a specific file and tool."""
    applicable = []
    
    for hook in hooks:
        if hook_applies(hook, file_path, tool, project_root):
            applicable.append(hook)
    
    # Sort by priority
    return sorted(applicable, key=lambda h: -h.get('priority', 50))


def hook_applies(hook: Dict[str, Any], file_path: str,
                tool: Optional[str], project_root: str) -> bool:
    """Check if a hook applies to a file and tool."""
    # Check if disabled
    if hook.get('disabled', False):
        return False
    
    # Check file patterns
    if not matches_file_patterns(hook, file_path):
        return False
    
    # Check tool filter
    if not matches_tool_filter(hook, tool):
        return False
    
    # Check directory filter
    if not matches_directory_filter(hook, file_path, project_root):
        return False
    
    return True


def matches_file_patterns(hook: Dict[str, Any], file_path: str) -> bool:
    """Check if file matches hook patterns."""
    patterns = hook.get('file_patterns')
    if not patterns:
        return True
    
    filename = os.path.basename(file_path)
    return any(fnmatch.fnmatch(filename, p) for p in patterns)


def matches_tool_filter(hook: Dict[str, Any], tool: Optional[str]) -> bool:
    """Check if tool matches hook filter."""
    tools = hook.get('tools')
    if not tools or '*' in tools:
        return True
    if not tool:
        return False
    return tool in tools


def matches_directory_filter(hook: Dict[str, Any], file_path: str,
                           project_root: str) -> bool:
    """Check if file is in allowed directories."""
    directories = hook.get('directories')
    if not directories:
        return True
    
    try:
        rel_path = os.path.relpath(file_path, project_root)
        return any(is_in_directory(rel_path, d) for d in directories)
    except ValueError:
        return False


def is_in_directory(file_path: str, directory: str) -> bool:
    """Check if file is in a specific directory."""
    starts_with_sep = file_path.startswith(directory + os.sep)
    equals_dir = file_path == directory
    starts_with_slash = ('/' in file_path and
                        file_path.startswith(directory + '/'))
    return starts_with_sep or equals_dir or starts_with_slash