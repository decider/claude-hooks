#!/usr/bin/env python3
"""Portable code quality validator - cleaner version."""

import json
import sys
import os
import re
import glob
from pathlib import Path

# Configuration
CONFIG = {
    'max_func_len': 30,
    'max_file_len': 200,
    'max_line_len': 100,
    'max_nest': 3,
}

def get_file_type(filepath):
    """Determine file type from extension."""
    ext = Path(filepath).suffix.lower()
    if ext in ['.ts', '.tsx', '.js', '.jsx']:
        return 'js'
    elif ext == '.py':
        return 'python'
    return 'unknown'

def check_line_length(lines):
    """Check for lines that are too long."""
    violations = []
    for i, line in enumerate(lines, 1):
        length = len(line.rstrip())
        if length > CONFIG['max_line_len']:
            violations.append(
                f"Line {i}: {length} chars (max: {CONFIG['max_line_len']})"
            )
    return violations

def check_python_funcs(lines):
    """Check Python function lengths."""
    violations = []
    func_start = 0
    func_name = ""
    
    for i, line in enumerate(lines, 1):
        match = re.match(r'^\s*def\s+(\w+)', line)
        if not match:
            continue
            
        if func_start > 0:
            length = i - func_start
            if length > CONFIG['max_func_len']:
                violations.append(f"Function '{func_name}': {length} lines")
        
        func_name = match.group(1)
        func_start = i
    
    # Check last function
    if func_start > 0:
        length = len(lines) - func_start + 1
        if length > CONFIG['max_func_len']:
            violations.append(f"Function '{func_name}': {length} lines")
    
    return violations

def check_nesting(lines, file_type):
    """Check nesting depth."""
    violations = []
    max_nest = CONFIG['max_nest']
    
    for i, line in enumerate(lines, 1):
        if not line.strip():
            continue
        
        # Count indentation
        indent = len(line) - len(line.lstrip())
        depth = indent // 4 if file_type == 'python' else indent // 2
        
        if depth > max_nest:
            violations.append(f"Line {i}: nesting {depth} (max: {max_nest})")
    
    return violations

def read_file_lines(filepath):
    """Read file and return lines."""
    try:
        with open(filepath, 'r') as f:
            return f.readlines()
    except:
        return None

def validate_file(filepath):
    """Validate a single file."""
    if not os.path.exists(filepath):
        return []
    
    file_type = get_file_type(filepath)
    if file_type == 'unknown':
        return []
    
    lines = read_file_lines(filepath)
    if lines is None:
        return []
    
    violations = []
    
    # File length
    if len(lines) > CONFIG['max_file_len']:
        violations.append(
            f"File: {len(lines)} lines (max: {CONFIG['max_file_len']})"
        )
    
    # Various checks
    violations.extend(check_line_length(lines))
    if file_type == 'python':
        violations.extend(check_python_funcs(lines))
    violations.extend(check_nesting(lines, file_type))
    
    return violations

def handle_post_tool(data):
    """Handle PostToolUse event."""
    tool = data.get('tool_name', '')
    if tool not in ['Write', 'Edit', 'MultiEdit']:
        return
    
    filepath = data.get('tool_input', {}).get('file_path', '')
    if not filepath:
        return
    
    violations = validate_file(filepath)
    if violations:
        # Provide strong warning but don't block
        print(f"\n⚠️  WARNING: Code quality issues in {filepath}:", file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        print("\n🚨 YOU WILL BE BLOCKED at session end if these aren't fixed!", file=sys.stderr)
        print("   Fix these issues now to avoid being blocked later.\n", file=sys.stderr)

def handle_stop():
    """Handle Stop event."""
    files = glob.glob('**/*.py', recursive=True)
    all_violations = []
    
    for filepath in files:
        violations = validate_file(filepath)
        for v in violations:
            all_violations.append(f"{filepath}: {v}")
    
    if all_violations:
        msg = "Quality issues found:\n"
        msg += "\n".join(f"  - {v}" for v in all_violations)
        print(json.dumps({"decision": "block", "reason": msg}))
        sys.exit(0)

def main():
    """Main entry point."""
    try:
        data = json.loads(sys.stdin.read())
    except:
        sys.exit(0)
    
    event = data.get('hook_event_name', '')
    
    if event == 'PostToolUse':
        handle_post_tool(data)
    elif event == 'Stop':
        handle_stop()
    
    sys.exit(0)

if __name__ == '__main__':
    main()