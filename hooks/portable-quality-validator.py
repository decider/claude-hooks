#!/usr/bin/env python3
"""Portable code quality validator - no external dependencies."""

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

def check_function_length(lines, file_type):
    """Check for functions that are too long."""
    violations = []
    in_function = False
    function_start = 0
    function_name = ""
    brace_count = 0
    
    for i, line in enumerate(lines, 1):
        # JavaScript/TypeScript function detection
        if file_type in ['typescript', 'javascript']:
            pattern = r'^\s*(function|const|let|var|export|async)\s+(\w+)\s*(\(|=.*\(|=.*async.*\()'
            match = re.match(pattern, line)
            if match and not in_function:
                in_function = True
                function_start = i
                function_name = match.group(2)
                brace_count = line.count('{') - line.count('}')
            
            if in_function:
                brace_count += line.count('{') - line.count('}')
                if brace_count == 0 and '{' in line:
                    length = i - function_start + 1
                    if length > CONFIG['max_function_length']:
                        msg = f"Function '{function_name}' is {length} lines"
                        violations.append(f"{msg} long (max: {CONFIG['max_function_length']})")
                    in_function = False
        
        # Python function detection
        elif file_type == 'python':
            if re.match(r'^\s*def\s+\w+\s*\(', line) or re.match(r'^\s*async\s+def\s+\w+\s*\(', line):
                if in_function and function_name:
                    length = i - function_start
                    if length > CONFIG['max_function_length']:
                        msg = f"Function '{function_name}' is {length} lines"
                        violations.append(f"{msg} long (max: {CONFIG['max_function_length']})")
                match = re.match(r'^\s*(?:async\s+)?def\s+(\w+)', line)
                function_name = match.group(1) if match else "unknown"
                function_start = i
                in_function = True
    
    # Handle function at end of file
    if in_function and function_name and file_type == 'python':
        length = len(lines) - function_start + 1
        if length > CONFIG['max_function_length']:
            msg = f"Function '{function_name}' is {length} lines"
            violations.append(f"{msg} long (max: {CONFIG['max_function_length']})")
    
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
            violations.append(f"{msg} (max: {CONFIG['max_line_length']})")
    return violations

def check_nesting_depth(lines, file_type):
    """Check for excessive nesting depth."""
    violations = []
    max_nesting = CONFIG.get(f'{file_type}_max_nesting', CONFIG['max_nesting_depth'])
    
    for i, line in enumerate(lines, 1):
        if not line.strip():
            continue
            
        # Count leading spaces/tabs
        indent_level = len(line) - len(line.lstrip())
        if '\t' in line[:indent_level]:
            indent_level = line[:indent_level].count('\t') * 4 + line[:indent_level].count(' ')
        
        # Estimate nesting based on indentation
        nesting = indent_level // 4 if file_type == 'python' else indent_level // 2
        
        if nesting > max_nesting:
            msg = f"Line {i} has nesting depth of {nesting}"
            violations.append(f"{msg} (max: {max_nesting})")
    
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
    violations.extend(check_file_length(lines))
    violations.extend(check_line_length(lines))
    violations.extend(check_function_length(lines, file_type))
    violations.extend(check_nesting_depth(lines, file_type))
    
    return violations

def handle_post_tool_use(data):
    """Handle PostToolUse event."""
    tool_name = data.get('tool_name', '')
    if tool_name not in ['Write', 'Edit', 'MultiEdit']:
        sys.exit(0)
    
    tool_input = data.get('tool_input', {})
    filepath = tool_input.get('file_path', '')
    
    if filepath:
        violations = validate_file(filepath)
        if violations:
            # Provide strong warning but don't block
            print(f"\n⚠️  WARNING: Code quality issues in {filepath}:", file=sys.stderr)
            for v in violations:
                print(f"  - {v}", file=sys.stderr)
            print("\n🚨 YOU WILL BE BLOCKED at session end if these aren't fixed!", file=sys.stderr)
            print("   Fix these issues now to avoid being blocked later.\n", file=sys.stderr)

def handle_stop_event():
    """Handle Stop event."""
    import glob
    # Check all Python files recursively
    python_files = glob.glob('**/*.py', recursive=True)
    
    all_violations = []
    for filepath in python_files:
        violations = validate_file(filepath)
        if violations:
            all_violations.extend([f"{filepath}: {v}" for v in violations])
    
    if all_violations:
        msg_lines = ["Code quality issues found at session end:"]
        msg_lines.extend(f"  - {v}" for v in all_violations)
        print(json.dumps({
            "decision": "block",
            "reason": "\n".join(msg_lines)
        }))
        sys.exit(0)

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
    
    if hook_event == 'PostToolUse':
        handle_post_tool_use(data)
    elif hook_event == 'Stop':
        handle_stop_event()
    
    sys.exit(0)

if __name__ == '__main__':
    main()