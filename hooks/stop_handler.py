#!/usr/bin/env python3
"""Stop event handling for code quality validation."""

import json
import sys
import glob
from validators import DEFAULT_CONFIG


def categorize_violations(violations_dict, filepath):
    """Categorize violations by type."""
    result = {
        'nesting': [],
        'long_lines': [],
        'long_functions': [],
        'long_files': []
    }
    
    # Convert new dict format to categorized format
    for v in violations_dict.get('file_length', []):
        result['long_files'].append((filepath, v))
    
    for v in violations_dict.get('line_length', []):
        result['long_lines'].append((filepath, v))
        
    for v in violations_dict.get('function_length', []):
        result['long_functions'].append((filepath, v))
        
    for v in violations_dict.get('nesting_depth', []):
        result['nesting'].append((filepath, v))
    
    return result


def format_violation_group(title, fix_msg, violations):
    """Format a group of violations."""
    lines = []
    lines.append(title)
    lines.append(f"   Fix: {fix_msg}")
    for filepath, v in violations:
        lines.append(f"   - {filepath}: {v}")
    lines.append("")
    return lines


def collect_all_violations(validate_file_func):
    """Collect and categorize all violations from Python files."""
    python_files = glob.glob('**/*.py', recursive=True)
    all_violations = {
        'nesting': [],
        'long_lines': [],
        'long_functions': [],
        'long_files': []
    }
    
    for filepath in python_files:
        violations_dict = validate_file_func(filepath)
        if not any(violations_dict.values()):
            continue
            
        cats = categorize_violations(violations_dict, filepath)
        for key in all_violations:
            all_violations[key].extend(cats[key])
    
    return all_violations


def add_violation_sections(msg_lines, all_violations, config):
    """Add violation sections to message lines."""
    violation_configs = [
        ('long_files', "❌ LONG FILES (max: {} lines)".format(
            config.get('max_file_length', DEFAULT_CONFIG['max_file_length'])),
         "Split into multiple modules (e.g., validators.py, handlers.py)"),
        ('long_lines', "❌ LONG LINES (max: {} chars)".format(
            config.get('max_line_length', DEFAULT_CONFIG['max_line_length'])),
         "Break lines using parentheses or line continuation"),
        ('long_functions', "❌ LONG FUNCTIONS (max: {} lines)".format(
            config.get('max_function_length', DEFAULT_CONFIG['max_function_length'])),
         "Split into smaller helper functions. Extract logical sections."),
        ('nesting', "❌ EXCESSIVE NESTING (max: {})".format(
            config.get('max_nesting_depth', DEFAULT_CONFIG['max_nesting_depth'])),
         "Extract nested logic into separate functions or use early returns")
    ]
    
    for key, title, fix_msg in violation_configs:
        if not all_violations[key]:
            continue
        msg_lines.extend(format_violation_group(
            title, fix_msg, all_violations[key]
        ))


def build_violation_message(all_violations, config):
    """Build the violation message."""
    msg_lines = [""]
    msg_lines.append("=" * 60)
    msg_lines.append("CODE QUALITY VIOLATIONS DETECTED")
    msg_lines.append("=" * 60)
    msg_lines.append("")
    
    total_violations = sum(len(v) for v in all_violations.values())
    msg_lines.append(f"Found {total_violations} total code quality violations")
    msg_lines.append("")
    
    add_violation_sections(msg_lines, all_violations, config)
    
    msg_lines.append("=" * 60)
    msg_lines.append("CLEAN CODE PRINCIPLES")
    msg_lines.append("=" * 60)
    msg_lines.append("")
    msg_lines.append("Please refactor your code following these principles:")
    msg_lines.append("- Keep functions small and focused (single responsibility)")
    msg_lines.append("- Reduce nesting depth (use early returns, extract logic)")
    msg_lines.append("- Break long lines for readability")
    msg_lines.append("- Split large files into logical modules")
    msg_lines.append("")
    msg_lines.append("ACTION REQUIRED: Fix all violations above to proceed.")
    return "\n".join(msg_lines)


def handle_stop_event(validate_file_func, config):
    """Handle Stop event."""
    all_violations = collect_all_violations(validate_file_func)
    
    if any(all_violations.values()):
        message = build_violation_message(all_violations, config)
        print(json.dumps({
            "decision": "block",
            "reason": message
        }))
        sys.exit(0)