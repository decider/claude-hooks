#!/usr/bin/env python3
"""Language-specific validation functions."""

import re


def _is_js_function_start(line):
    """Check if line starts a JS/TS function."""
    pat = r'^\s*(function|const|let|var|export|async)\s+(\w+)\s*(\(|=.*\(|=.*async.*\()'
    return re.match(pat, line)


def _process_js_function_start(line, line_num, func_state):
    """Process potential JavaScript function start."""
    match = _is_js_function_start(line)
    if not match:
        return
        
    func_state['in_func'] = True
    func_state['start'] = line_num
    func_state['name'] = match.group(2)
    func_state['braces'] = line.count('{') - line.count('}')
    return


def _check_js_function_end(func_state, line, i, violations, max_len):
    """Check if function ends and validate length."""
    func_state['braces'] += line.count('{') - line.count('}')
    
    if func_state['braces'] != 0 or '{' not in line:
        return False
        
    length = i - func_state['start'] + 1
    if length > max_len:
        violations.append(
            f"Function '{func_state['name']}' at line {func_state['start']}: "
            f"{length} lines (max: {max_len})"
        )
    return True


def _process_js_line(line, i, func_state, violations, max_len):
    """Process a single line for JavaScript function checking."""
    if not func_state['in_func']:
        _process_js_function_start(line, i, func_state)
        return
        
    # In function - check if it ends
    if _check_js_function_end(func_state, line, i, violations, max_len):
        func_state['in_func'] = False


def check_js_functions(lines, violations, max_len):
    """Check JavaScript/TypeScript functions."""
    func_state = {'in_func': False, 'start': 0, 'name': '', 'braces': 0}
    
    for i, line in enumerate(lines, 1):
        _process_js_line(line, i, func_state, violations, max_len)


def _is_py_function_start(line):
    """Check if line starts a Python function."""
    return re.match(r'^\s*(?:async\s+)?def\s+\w+\s*\(', line)


def _validate_py_function_length(name, start, end, max_len, violations):
    """Validate Python function length."""
    length = end - start
    if length > max_len:
        violations.append(
            f"Function '{name}' at line {start}: {length} lines (max: {max_len})"
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