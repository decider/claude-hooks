#!/usr/bin/env python3
"""Configuration loader for hierarchical hook configs."""

import os
import json
import copy
import functools
import fnmatch
from pathlib import Path

# Project root is parent of hooks directory
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def _read_json(path):
    """Read a JSON file safely."""
    try:
        with open(path, "r") as f:
            return json.load(f)
    except:
        return {}

def _merge(base, override):
    """Merge override config into base config."""
    merged = copy.deepcopy(base)
    
    for phase in ("pre-tool", "post-tool", "stop"):
        # Create lookup dicts by hook ID
        over_hooks = {h["id"]: h for h in override.get(phase, [])}
        base_hooks = {h["id"]: h for h in merged.get(phase, [])}
        
        # Apply overrides
        for hid, hook in over_hooks.items():
            if hook.get("disable"):
                # Remove disabled hooks
                base_hooks.pop(hid, None)
            elif hid in base_hooks:
                # Update existing hook
                base_hooks[hid].update(hook)
            else:
                # Add new hook
                base_hooks[hid] = hook
        
        # Convert back to list
        merged[phase] = list(base_hooks.values())
    
    return merged

def _collect_configs(start_dir):
    """Collect all config files from start_dir up to project root."""
    configs = []
    cur = os.path.abspath(start_dir)
    
    # Walk up from current dir to project root
    while cur.startswith(ROOT):
        cfg_path = os.path.join(cur, ".claude-hooks.json")
        if os.path.isfile(cfg_path):
            configs.append(_read_json(cfg_path))
        cur = os.path.dirname(cur)
    
    # Add root config last (lowest priority)
    root_cfg = _read_json(os.path.join(ROOT, ".claude", "hooks.json"))
    configs.append(root_cfg)
    
    # Return in order from root to specific
    return reversed(configs)

@functools.lru_cache(maxsize=2048)
def effective_config(file_path):
    """Get effective config for a file by merging all parent configs."""
    file_path = os.path.abspath(file_path)
    merged = {}
    
    # Merge configs from root to specific
    for cfg in _collect_configs(os.path.dirname(file_path)):
        merged = _merge(merged, cfg)
    
    return merged

def matches_patterns(patterns, path):
    """Check if path matches any of the given patterns."""
    filename = os.path.basename(path)
    return any(fnmatch.fnmatch(filename, p) for p in patterns)

def get_hooks_for_phase(file_path, phase):
    """Get all hooks for a specific phase and file."""
    config = effective_config(file_path)
    hooks = config.get(phase, [])
    
    # Filter by file patterns and sort by priority
    applicable = []
    for hook in hooks:
        patterns = hook.get("file_patterns", ["*"])
        if matches_patterns(patterns, file_path):
            applicable.append(hook)
    
    # Sort by priority (highest first)
    return sorted(applicable, key=lambda h: h.get("priority", 0), reverse=True)