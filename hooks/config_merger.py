#!/usr/bin/env python3
"""Configuration merging utilities for Claude Hooks."""

from typing import Dict, List, Any


def merge_configs(base: Dict[str, Any], overlay: Dict[str, Any]) -> Dict[str, Any]:
    """Merge two configurations, with overlay taking precedence."""
    result = base.copy()
    
    # Simple merge for non-hook fields
    for key, value in overlay.items():
        if key not in ['hooks', 'exclude']:
            result[key] = value
    
    # Merge hooks
    result['hooks'] = merge_hooks(
        base.get('hooks', {}),
        overlay.get('hooks', {}),
        overlay.get('exclude', [])
    )
    
    return result


def merge_hooks(base_hooks: Dict, overlay_hooks: Dict, 
                exclude_ids: List[str]) -> Dict:
    """Merge hook configurations."""
    result = {}
    
    # Process each event type
    for event_type in ['pre-tool', 'post-tool', 'stop']:
        merged = merge_hook_list(
            base_hooks.get(event_type, []),
            overlay_hooks.get(event_type, []),
            exclude_ids
        )
        if merged:
            result[event_type] = merged
    
    return result


def merge_hook_list(base_list: List[Dict], overlay_list: List[Dict],
                    exclude_ids: List[str]) -> List[Dict]:
    """Merge two lists of hooks."""
    # Create lookup for overlay hooks
    overlay_by_id = {h.get('id'): h for h in overlay_list if h.get('id')}
    
    merged = []
    
    # Add base hooks (excluding overridden/excluded)
    for hook in base_list:
        hook_id = hook.get('id')
        if hook_id in exclude_ids:
            continue
        if hook_id in overlay_by_id:
            continue
        merged.append(hook.copy())
    
    # Add overlay hooks
    merged.extend(h.copy() for h in overlay_list)
    
    return merged