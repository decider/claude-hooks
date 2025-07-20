#!/usr/bin/env python3
"""
Hierarchical configuration loader for Claude Hooks.
Supports inheritance, file patterns, and directory-based filtering.
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Any

from config_merger import merge_configs
from hook_filter import filter_hooks_for_file


class HierarchicalConfigLoader:
    """Load and merge hierarchical hook configurations."""
    
    def __init__(self, project_root: Optional[str] = None):
        """Initialize the loader with the project root."""
        self.project_root = project_root or self._find_project_root()
        self._config_cache = {}
        self._file_cache = {}
    
    def _find_project_root(self) -> str:
        """Find the project root by looking for .git or .claude directories."""
        current = os.getcwd()
        while current != '/':
            if os.path.exists(os.path.join(current, '.git')):
                return current
            if os.path.exists(os.path.join(current, '.claude')):
                return current
            current = os.path.dirname(current)
        return os.getcwd()
    
    def get_config_for_path(self, file_path: str) -> Dict[str, Any]:
        """Get the merged configuration for a specific file path."""
        # Cache lookup
        cache_key = os.path.abspath(file_path)
        if cache_key in self._config_cache:
            return self._config_cache[cache_key]
        
        # Load and merge all configs
        configs = self._find_config_files(file_path)
        merged = self._merge_all_configs(configs)
        
        # Cache result
        self._config_cache[cache_key] = merged
        return merged
    
    def _find_config_files(self, file_path: str) -> List[str]:
        """Find all configuration files that apply to this path."""
        configs = []
        
        # Add root config if exists
        root_config = self._get_root_config_path()
        if root_config and os.path.exists(root_config):
            configs.append(root_config)
        
        # Add directory-specific configs
        configs.extend(self._find_directory_configs(file_path))
        
        return configs
    
    def _get_root_config_path(self) -> Optional[str]:
        """Get the root configuration file path."""
        return os.path.join(self.project_root, '.claude', 'hookconfig.json')
    
    def _find_directory_configs(self, file_path: str) -> List[str]:
        """Find configuration files in directories."""
        configs = []
        target_dir = os.path.dirname(os.path.abspath(file_path))
        
        if not self._is_path_in_project(target_dir):
            return configs
        
        path_parts = self._get_relative_path_parts(target_dir)
        if not path_parts:
            return configs
        
        # Check each directory level
        for i in range(len(path_parts)):
            current = os.path.join(self.project_root, *path_parts[:i+1])
            config_path = os.path.join(current, '.claude-hooks.json')
            if os.path.exists(config_path):
                configs.append(config_path)
        
        return configs
    
    def _is_path_in_project(self, path: str) -> bool:
        """Check if path is within project root."""
        try:
            current = os.path.abspath(self.project_root)
            rel_path = os.path.relpath(path, current)
            return rel_path == '.' or not rel_path.startswith('..')
        except ValueError:
            # Paths on different drives on Windows
            return False
    
    def _get_relative_path_parts(self, target_dir: str) -> List[str]:
        """Get path parts relative to project root."""
        try:
            current = os.path.abspath(self.project_root)
            rel_path = os.path.relpath(target_dir, current)
            if rel_path == '.':
                return []
            return rel_path.split(os.sep)
        except ValueError:
            return []
    
    def _load_config_file(self, config_path: str) -> Optional[Dict[str, Any]]:
        """Load a single configuration file."""
        if config_path in self._file_cache:
            return self._file_cache[config_path]
        
        config = self._read_config_file(config_path)
        if not config:
            return None
        
        # Handle extends
        if 'extends' in config:
            base_config = self._load_extended_config(config['extends'], config_path)
            if base_config:
                config = merge_configs(base_config, config)
        
        self._file_cache[config_path] = config
        return config
    
    def _read_config_file(self, config_path: str) -> Optional[Dict[str, Any]]:
        """Read and parse a configuration file."""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading {config_path}: {e}", file=os.sys.stderr)
            return None
    
    def _load_extended_config(self, extends: str, current_path: str) -> Optional[Dict[str, Any]]:
        """Load configuration that this one extends."""
        if extends.startswith('@'):
            # Predefined configs (future feature)
            return None
        
        # Resolve relative path
        base_path = os.path.join(os.path.dirname(current_path), extends)
        if os.path.exists(base_path):
            return self._load_config_file(base_path)
        
        # Try from project root
        root_path = os.path.join(self.project_root, extends)
        if os.path.exists(root_path):
            return self._load_config_file(root_path)
        
        return None
    
    def _merge_all_configs(self, config_paths: List[str]) -> Dict[str, Any]:
        """Merge all configuration files."""
        result = {}
        
        for config_path in config_paths:
            config = self._load_config_file(config_path)
            if config:
                result = merge_configs(result, config)
        
        return result
    
    def get_hooks_for_file(self, file_path: str, event_type: str,
                          tool: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get hooks that apply to a specific file and event."""
        config = self.get_config_for_path(file_path)
        hooks = config.get('hooks', {}).get(event_type, [])
        
        return filter_hooks_for_file(hooks, file_path, tool, self.project_root)


# Convenience function
def effective_config(file_path: str) -> Dict[str, Any]:
    """Get the effective configuration for a file path."""
    loader = HierarchicalConfigLoader()
    return loader.get_config_for_path(file_path)