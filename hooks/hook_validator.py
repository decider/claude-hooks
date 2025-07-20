#!/usr/bin/env python3
"""Hook configuration validation utilities."""

import json
import os
from pathlib import Path
from typing import List, Tuple, Dict, Any


def validate_config_file(config_path: Path, project_root: Path) -> Tuple[List[str], List[str]]:
    """
    Validate a single configuration file.
    Returns (errors, warnings) as lists of strings.
    """
    errors = []
    warnings = []
    rel_path = config_path.relative_to(project_root)
    
    # Read and parse file
    content = _read_file_content(config_path)
    if not content:
        warnings.append(f"{rel_path}: Empty configuration file")
        return errors, warnings
    
    # Parse JSON
    config = _parse_json_config(content, rel_path, errors)
    if not config:
        return errors, warnings
    
    # Validate structure
    if 'hooks' in config:
        _validate_hooks_structure(config['hooks'], rel_path, errors, warnings, project_root)
    
    return errors, warnings


def _read_file_content(config_path: Path) -> str:
    """Read file content safely."""
    try:
        with open(config_path, 'r') as f:
            content = f.read()
            return content.strip()
    except Exception:
        return ""


def _parse_json_config(content: str, rel_path: Path, errors: List[str]) -> Dict[str, Any]:
    """Parse JSON configuration."""
    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        errors.append(f"{rel_path}: Invalid JSON - {e}")
        return {}


def _validate_hooks_structure(hooks: Any, rel_path: Path, errors: List[str],
                             warnings: List[str], project_root: Path):
    """Validate the hooks structure."""
    if not isinstance(hooks, dict):
        errors.append(f"{rel_path}: 'hooks' must be an object")
        return
    
    for event_type, hook_list in hooks.items():
        _validate_event_type(event_type, hook_list, rel_path, errors, warnings, project_root)


def _validate_event_type(event_type: str, hook_list: Any, rel_path: Path,
                        errors: List[str], warnings: List[str], project_root: Path):
    """Validate a single event type and its hooks."""
    valid_events = ['pre-tool', 'post-tool', 'stop']
    
    if event_type not in valid_events:
        warnings.append(f"{rel_path}: Unknown event type '{event_type}'")
    
    if not isinstance(hook_list, list):
        errors.append(f"{rel_path}: hooks.{event_type} must be an array")
        return
    
    for i, hook in enumerate(hook_list):
        _validate_single_hook(hook, event_type, i, rel_path, errors, warnings, project_root)


def _validate_single_hook(hook: Dict[str, Any], event_type: str, index: int,
                         rel_path: Path, errors: List[str], warnings: List[str],
                         project_root: Path):
    """Validate a single hook configuration."""
    # Check required fields
    if 'id' not in hook:
        errors.append(f"{rel_path}: hooks.{event_type}[{index}] missing required 'id' field")
    
    if 'script' not in hook:
        errors.append(f"{rel_path}: hooks.{event_type}[{index}] missing required 'script' field")
    
    # Check script exists
    if 'script' in hook:
        script_path = project_root / 'hooks' / hook['script']
        if not script_path.exists():
            warnings.append(f"{rel_path}: Script '{hook['script']}' not found")


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