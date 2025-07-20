#!/usr/bin/env python3
"""Code quality validation functions."""

import re
from pathlib import Path

# Configuration
CONFIG = {
    'max_function_length': 30,
    'max_file_length': 200,
    'max_line_length': 100,
    'max_nesting_depth': 4,
    'python_max_nesting': 3,
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

def _is_js_function_start(line):
    """Check if line starts a JS/TS function."""
    pat = r'^\s*(function|const|let|var|export|async)\s+(\w+)\s*(\(|=.*\(|=.*async.*\()'
    return re.match(pat, line)

def _check_js_function_end(func_state, line, i, violations, max_len):
    """Check if function ends and validate length."""
    func_state['braces'] += line.count('{') - line.count('}')
    
    if func_state['braces'] != 0 or '{' not in line:
        return False
        
    length = i - func_state['start'] + 1
    if length > max_len:
        violations.append(
            f"Function '{func_state['name']}' is {length} lines long (max: {max_len})"
        )
    return True

def check_js_functions(lines, violations, max_len):
    """Check JavaScript/TypeScript functions."""
    func_state = {'in_func': False, 'start': 0, 'name': '', 'braces': 0}
    
    for i, line in enumerate(lines, 1):
        if not func_state['in_func']:
            match = _is_js_function_start(line)
            if not match:
                continue
            func_state['in_func'] = True
            func_state['start'] = i
            func_state['name'] = match.group(2)
            func_state['braces'] = line.count('{') - line.count('}')
            continue
            
        # In function - check for end
        if _check_js_function_end(func_state, line, i, violations, max_len):
            func_state['in_func'] = False

def _is_py_function_start(line):
    """Check if line starts a Python function."""
    return re.match(r'^\s*(?:async\s+)?def\s+\w+\s*\(', line)

def _validate_py_function_length(name, start, end, max_len, violations):
    """Validate Python function length."""
    length = end - start
    if length > max_len:
        violations.append(
            f"Function '{name}' is {length} lines long (max: {max_len})"
        )

def check_py_functions(lines, violations, max_len):
    """Check Python functions."""
    in_func = False
    func_start = 0
    func_name = ""
    
    for i, line in enumerate(lines, 1):
        if not _is_py_function_start(line):
            continue
            
        # Check previous function if exists
        if in_func and func_name:
            _validate_py_function_length(func_name, func_start, i, max_len, violations)
            
        # Start new function
        match = re.match(r'^\s*(?:async\s+)?def\s+(\w+)', line)
        func_name = match.group(1) if match else "unknown"
        func_start = i
        in_func = True
    
    # Handle last function
    if in_func and func_name:
        _validate_py_function_length(func_name, func_start, len(lines) + 1, max_len, violations)

def check_function_length(lines, file_type):
    """Check for functions that are too long."""
    violations = []
    max_len = CONFIG['max_function_length']
    
    if file_type in ['typescript', 'javascript']:
        check_js_functions(lines, violations, max_len)
    elif file_type == 'python':
        check_py_functions(lines, violations, max_len)
    
    return violations

def check_file_length(lines):
    """Check if file is too long."""
    if len(lines) > CONFIG['max_file_length']:
        return [f"File is {len(lines)} lines long (max: {CONFIG['max_file_length']})"]
    return []

def check_line_length(lines):
    """Check for lines that are too long."""
    violations = []
    for i, line in enumerate(lines, 1):
        length = len(line.rstrip())
        if length > CONFIG['max_line_length']:
            msg = f"Line {i} is {length} characters long"
            violations.append(
                f"{msg} (max: {CONFIG['max_line_length']})"
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

def check_nesting_depth(lines, file_type):
    """Check for excessive nesting depth."""
    violations = []
    py_max = CONFIG.get('python_max_nesting', 3)
    other_max = CONFIG['max_nesting_depth']
    max_nest = py_max if file_type == 'python' else other_max
    divisor = 4 if file_type == 'python' else 2
    
    for i, line in enumerate(lines, 1):
        if not line.strip():
            continue
            
        indent = _calculate_indent_level(line)
        nest = indent // divisor
        
        if nest > max_nest:
            violations.append(
                f"Line {i} has nesting depth of {nest} (max: {max_nest})"
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