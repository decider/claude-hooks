#!/usr/bin/env python3
"""Hierarchical configuration loader for Claude hooks - no external dependencies."""

import os
import copy
import json
from pathlib import Path
from typing import Dict, List, Any, Optional
import fnmatch


class HierarchicalConfigLoader:
    """Load and merge hierarchical hook configurations using JSON."""
    
    def __init__(self, project_root: Optional[str] = None):
        self.project_root = project_root or self._find_project_root()
        self._config_cache = {}
        self._file_cache = {}
    
    def _find_project_root(self) -> str:
        """Find project root by looking for .git or .claude directory."""
        current = Path.cwd()
        while current != current.parent:
            if (current / '.git').exists() or (current / '.claude').exists():
                return str(current)
            current = current.parent
        return str(Path.cwd())
    
    def get_config_for_path(self, file_path: str) -> Dict[str, Any]:
        """Get merged configuration for a specific file path."""
        # Normalize path
        if not os.path.isabs(file_path):
            file_path = os.path.join(self.project_root, file_path)
        
        cache_key = os.path.dirname(file_path)
        
        if cache_key in self._config_cache:
            return self._config_cache[cache_key]
        
        # Collect all config files from root to file directory
        config_files = self._find_config_files(file_path)
        
        # Start with empty config
        merged = {'version': '1.0', 'hooks': {}}
        
        # Merge configurations from root to leaf
        for config_file in config_files:
            config = self._load_config_file(config_file)
            if config:
                merged = self._merge_configs(merged, config)
        
        self._config_cache[cache_key] = merged
        return merged
    
    def _find_config_files(self, file_path: str) -> List[str]:
        """Find all configuration files from root to file path."""
        configs = []
        
        # First check for root .claude/hookconfig.json
        root_config = os.path.join(self.project_root, '.claude', 'hookconfig.json')
        if os.path.exists(root_config):
            configs.append(root_config)
        
        # Walk from project root to file directory
        current = self.project_root
        target_dir = os.path.dirname(file_path)
        
        # Get relative path components
        try:
            rel_path = os.path.relpath(target_dir, current)
            if rel_path != '.' and not rel_path.startswith('..'):
                path_parts = rel_path.split(os.sep)
                
                # Check each directory level
                for i in range(len(path_parts)):
                    current = os.path.join(self.project_root, *path_parts[:i+1])
                    config_path = os.path.join(current, '.claude-hooks.json')
                    if os.path.exists(config_path):
                        configs.append(config_path)
        except ValueError:
            # Paths on different drives on Windows
            pass
        
        return configs
    
    def _load_config_file(self, config_path: str) -> Optional[Dict[str, Any]]:
        """Load a single configuration file."""
        if config_path in self._file_cache:
            return self._file_cache[config_path]
        
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
                
            # Handle extends
            if 'extends' in config:
                base_config = self._load_extended_config(config['extends'], config_path)
                if base_config:
                    config = self._merge_configs(base_config, config)
            
            self._file_cache[config_path] = config
            return config
        except Exception as e:
            print(f"Error loading {config_path}: {e}", file=os.sys.stderr)
            return None
    
    def _load_extended_config(self, extends: str, current_path: str) -> Optional[Dict[str, Any]]:
        """Load configuration that this one extends."""
        if extends.startswith('@'):
            # Handle team/shared configs (placeholder for future)
            return None
        
        # Resolve relative path
        base_dir = os.path.dirname(current_path)
        extended_path = os.path.normpath(os.path.join(base_dir, extends))
        
        if not extended_path.endswith('.json'):
            extended_path = os.path.join(extended_path, '.claude-hooks.json')
        
        if os.path.exists(extended_path):
            return self._load_config_file(extended_path)
        
        return None
    
    def _merge_configs(self, base: Dict[str, Any], override: Dict[str, Any]) -> Dict[str, Any]:
        """Merge two configurations with proper precedence."""
        merged = copy.deepcopy(base)
        
        # Handle excludes first
        if 'exclude' in override:
            for hook_id in override['exclude']:
                merged = self._remove_hook(merged, hook_id)
        
        # Merge hooks by event type
        for event_type in ['pre-tool', 'post-tool', 'stop']:
            if event_type in override.get('hooks', {}):
                if event_type not in merged.get('hooks', {}):
                    merged.setdefault('hooks', {})[event_type] = []
                
                # Process each hook in override
                for hook in override['hooks'][event_type]:
                    existing_idx = self._find_hook_index(merged['hooks'][event_type], hook['id'])
                    
                    if existing_idx is not None:
                        # Update existing hook
                        merged['hooks'][event_type][existing_idx] = self._merge_hook_configs(
                            merged['hooks'][event_type][existing_idx], hook
                        )
                    else:
                        # Add new hook
                        merged['hooks'][event_type].append(hook)
        
        # Copy other top-level keys
        for key in override:
            if key not in ['hooks', 'exclude', 'extends']:
                merged[key] = override[key]
        
        return merged
    
    def _merge_hook_configs(self, base_hook: Dict[str, Any], override_hook: Dict[str, Any]) -> Dict[str, Any]:
        """Merge two hook configurations."""
        merged = copy.deepcopy(base_hook)
        
        # Simple override for most fields
        for key in ['script', 'priority', 'disabled']:
            if key in override_hook:
                merged[key] = override_hook[key]
        
        # Merge arrays
        for key in ['file_patterns', 'tools', 'directories']:
            if key in override_hook:
                if key in merged:
                    # Combine and deduplicate
                    merged[key] = list(set(merged[key] + override_hook[key]))
                else:
                    merged[key] = override_hook[key]
        
        # Deep merge config
        if 'config' in override_hook:
            if 'config' in merged:
                merged['config'].update(override_hook['config'])
            else:
                merged['config'] = override_hook['config']
        
        return merged
    
    def _remove_hook(self, config: Dict[str, Any], hook_id: str) -> Dict[str, Any]:
        """Remove a hook by ID from all event types."""
        result = copy.deepcopy(config)
        
        for event_type in ['pre-tool', 'post-tool', 'stop']:
            if event_type in result.get('hooks', {}):
                result['hooks'][event_type] = [
                    h for h in result['hooks'][event_type]
                    if h.get('id') != hook_id
                ]
        
        return result
    
    def _find_hook_index(self, hooks: List[Dict[str, Any]], hook_id: str) -> Optional[int]:
        """Find index of hook by ID."""
        for i, hook in enumerate(hooks):
            if hook.get('id') == hook_id:
                return i
        return None
    
    def get_hooks_for_file(self, file_path: str, event_type: str) -> List[Dict[str, Any]]:
        """Get all applicable hooks for a file and event type."""
        config = self.get_config_for_path(file_path)
        all_hooks = config.get('hooks', {}).get(event_type, [])
        
        # Filter hooks based on patterns
        applicable_hooks = []
        for hook in all_hooks:
            if hook.get('disabled', False):
                continue
                
            # Check file patterns
            if 'file_patterns' in hook:
                if not any(fnmatch.fnmatch(os.path.basename(file_path), pattern) 
                          for pattern in hook['file_patterns']):
                    continue
            
            # Check directories
            if 'directories' in hook:
                rel_path = os.path.relpath(file_path, self.project_root)
                if not any(rel_path.startswith(d) for d in hook['directories']):
                    continue
            
            applicable_hooks.append(hook)
        
        # Sort by priority (higher first)
        applicable_hooks.sort(key=lambda h: h.get('priority', 50), reverse=True)
        
        return applicable_hooks
    
    def get_hooks_for_tool(self, tool_name: str, event_type: str) -> List[Dict[str, Any]]:
        """Get all hooks that apply to a specific tool."""
        # For tool-based hooks, we use a dummy file path
        config = self.get_config_for_path(self.project_root)
        all_hooks = config.get('hooks', {}).get(event_type, [])
        
        applicable_hooks = []
        for hook in all_hooks:
            if hook.get('disabled', False):
                continue
            
            # Check if hook applies to this tool
            if 'tools' in hook:
                if tool_name not in hook['tools']:
                    continue
            
            applicable_hooks.append(hook)
        
        # Sort by priority (higher first)
        applicable_hooks.sort(key=lambda h: h.get('priority', 50), reverse=True)
        
        return applicable_hooks
    
    def clear_cache(self):
        """Clear all caches."""
        self._config_cache.clear()
        self._file_cache.clear()


# Convenience functions
_default_loader = None

def get_loader() -> HierarchicalConfigLoader:
    """Get the default config loader instance."""
    global _default_loader
    if _default_loader is None:
        _default_loader = HierarchicalConfigLoader()
    return _default_loader

def get_hooks_for_file(file_path: str, event_type: str) -> List[Dict[str, Any]]:
    """Get hooks for a file using the default loader."""
    return get_loader().get_hooks_for_file(file_path, event_type)

def get_hooks_for_tool(tool_name: str, event_type: str) -> List[Dict[str, Any]]:
    """Get hooks for a tool using the default loader."""
    return get_loader().get_hooks_for_tool(tool_name, event_type)

def get_config_for_path(file_path: str) -> Dict[str, Any]:
    """Get configuration for a path using the default loader."""
    return get_loader().get_config_for_path(file_path)