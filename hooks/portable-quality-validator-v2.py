#!/usr/bin/env python3
"""Portable code quality validator - using exit codes."""

import json
import sys
import os
import re
from pathlib import Path

# Configuration
CONFIG = {
    'max_function_length': 30,
    'max_file_length': 200,
    'max_line_length': 100,
    'max_nesting_depth': 4,
    'python_max_nesting': 3,
}

def get_file_type(filepath):
    """Determine file type from extension."""
    ext = Path(filepath).suffix.lower()
    return {
        '.ts': 'typescript', '.tsx': 'typescript',
        '.js': 'javascript', '.jsx': 'javascript',
        '.py': 'python', '.rb': 'ruby',
    }.get(ext, 'unknown')

def check_function_length(lines, file_type):
    """Check for functions that are too long."""
    violations = []
    
    if file_type == 'python':
        in_function = False
        function_start = 0
        function_name = ""
        
        for i, line in enumerate(lines, 1):
            if re.match(r'^\s*def\s+(\w+)', line):
                if in_function:
                    length = i - function_start
                    if length > CONFIG['max_function_length']:
                        violations.append(
                            f"Function '{function_name}' is {length} lines "
                            f"(max: {CONFIG['max_function_length']})"
                        )
                match = re.match(r'^\s*def\s+(\w+)', line)
                function_name = match.group(1)
                function_start = i
                in_function = True
        
        # Check last function
        if in_function:
            length = len(lines) - function_start + 1
            if length > CONFIG['max_function_length']:
                violations.append(
                    f"Function '{function_name}' is {length} lines "
                    f"(max: {CONFIG['max_function_length']})"
                )
    
    return violations

def check_line_length(lines):
    """Check for lines that are too long."""
    violations = []
    for i, line in enumerate(lines, 1):
        length = len(line.rstrip())
        if length > CONFIG['max_line_length']:
            violations.append(
                f"Line {i} is {length} characters "
                f"(max: {CONFIG['max_line_length']})"
            )
    return violations

def validate_file(filepath):
    """Validate a single file."""
    if not os.path.exists(filepath):
        return []
    
    file_type = get_file_type(filepath)
    if file_type == 'unknown':
        return []
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except:
        return []
    
    violations = []
    
    # Check file length
    if len(lines) > CONFIG['max_file_length']:
        violations.append(
            f"File is {len(lines)} lines "
            f"(max: {CONFIG['max_file_length']})"
        )
    
    violations.extend(check_line_length(lines))
    violations.extend(check_function_length(lines, file_type))
    
    return violations

def main():
    """Main entry point."""
    input_data = sys.stdin.read().strip()
    if not input_data:
        sys.exit(0)
    
    try:
        data = json.loads(input_data)
    except:
        sys.exit(0)
    
    hook_event = data.get('hook_event_name', '')
    if hook_event not in ['PostToolUse', 'Stop']:
        sys.exit(0)
    
    # PostToolUse: check specific file
    if hook_event == 'PostToolUse':
        tool_name = data.get('tool_name', '')
        if tool_name not in ['Write', 'Edit', 'MultiEdit']:
            sys.exit(0)
        
        filepath = data.get('tool_input', {}).get('file_path', '')
        if filepath:
            violations = validate_file(filepath)
            if violations:
                print(f"Code quality issues in {filepath}:", file=sys.stderr)
                for v in violations:
                    print(f"  - {v}", file=sys.stderr)
                sys.exit(2)  # Block with exit code 2
    
    # Stop: check all Python files
    elif hook_event == 'Stop':
        import glob
        all_violations = []
        for filepath in glob.glob('*.py'):
            violations = validate_file(filepath)
            if violations:
                for v in violations:
                    all_violations.append(f"{filepath}: {v}")
        
        if all_violations:
            print("Code quality issues found:", file=sys.stderr)
            for v in all_violations:
                print(f"  - {v}", file=sys.stderr)
            sys.exit(2)  # Block with exit code 2
    
    sys.exit(0)  # Continue

if __name__ == '__main__':
    main()