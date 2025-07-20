#!/usr/bin/env python3
"""Code quality validation functions."""

import re
from pathlib import Path
from language_validators import check_js_functions, check_py_functions

# Default configuration (can be overridden by CONFIG from portable-quality-validator.py)
DEFAULT_CONFIG = {
    'max_function_length': 30,
    'max_file_length': 200,
    'max_line_length': 100,
    'max_nesting_depth': 4,
    'python_max_nesting': 4,
    'ruby_max_nesting': 3,
}

def get_file_type(filepath):
    """Determine file type from extension."""
    ext = Path(filepath).suffix.lower()
    return {
        '.ts': 'typescript', '.tsx': 'typescript',
        '.js': 'javascript', '.jsx': 'javascript',
        '.py': 'python', '.rb': 'ruby',
        '.rs': 'rust', '.go': 'go',
    }.get(ext, 'unknown')


def check_function_length(lines, file_type, config=None):
    """Check for functions that are too long."""
    if config is None:
        config = DEFAULT_CONFIG
    violations = []
    max_len = config.get('max_function_length', DEFAULT_CONFIG['max_function_length'])
    
    if file_type in ['typescript', 'javascript']:
        check_js_functions(lines, violations, max_len)
    elif file_type == 'python':
        check_py_functions(lines, violations, max_len)
    
    return violations

def check_file_length(lines, config=None):
    """Check if file is too long."""
    if config is None:
        config = DEFAULT_CONFIG
    max_len = config.get('max_file_length', DEFAULT_CONFIG['max_file_length'])
    if len(lines) > max_len:
        return [f"File is {len(lines)} lines long (max: {max_len})"]
    return []

def check_line_length(lines, config=None):
    """Check for lines that are too long."""
    if config is None:
        config = DEFAULT_CONFIG
    violations = []
    max_len = config.get('max_line_length', DEFAULT_CONFIG['max_line_length'])
    
    for i, line in enumerate(lines, 1):
        # Skip lines that are just long strings or URLs
        if 'https://' in line or 'http://' in line:
            continue
            
        length = len(line.rstrip())
        if length <= max_len:
            continue
            
        violations.append(
            f"Line {i}: {length} characters (max: {max_len})"
        )
    return violations

def _calculate_indent_level(line):
    """Calculate indentation level for a line."""
    indent = len(line) - len(line.lstrip())
    if '\t' not in line[:indent]:
        return indent
    
    tabs = line[:indent].count('\t')
    spaces = line[:indent].count(' ')
    return tabs * 4 + spaces

def check_nesting_depth(lines, file_type, config=None):
    """Check for excessive nesting depth."""
    if config is None:
        config = DEFAULT_CONFIG
    violations = []
    py_max = config.get('python_max_nesting', DEFAULT_CONFIG['python_max_nesting'])
    other_max = config.get('max_nesting_depth', DEFAULT_CONFIG['max_nesting_depth'])
    max_nest = py_max if file_type == 'python' else other_max
    divisor = 4 if file_type == 'python' else 2
    
    for i, line in enumerate(lines, 1):
        if not line.strip():
            continue
            
        indent = _calculate_indent_level(line)
        nest = indent // divisor
        
        if nest <= max_nest:
            continue
            
        violations.append(
            f"Line {i}: nesting depth {nest} exceeds maximum {max_nest}"
        )
    
    return violations

def get_fix_instruction(violation):
    """Get actionable fix instruction for a violation."""
    if "lines long (max:" in violation:
        if "Function" in violation:
            return "Split into smaller helper functions. Extract logical sections."
        else:
            return "Split this file into multiple modules (e.g., validators.py, handlers.py)"
    elif "characters long" in violation:
        return "Break this line into multiple lines using parentheses or line continuation"
    elif "nesting depth" in violation:
        return "Extract nested logic into separate functions or use early returns"
    return "Refactor to meet quality standards"