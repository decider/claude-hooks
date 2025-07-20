#!/usr/bin/env python3
"""Portable code quality validator - main handler."""

import json
import sys
import os
import glob
from validators import (
    get_file_type,
    check_file_length,
    check_line_length,
    check_function_length,
    check_nesting_depth,
    get_fix_instruction
)

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
                print(f"    → Fix: {get_fix_instruction(v)}", file=sys.stderr)
            print("\n🚨 YOU WILL BE BLOCKED at session end if these aren't fixed!", file=sys.stderr)
            print("   FIX NOW: Address the issues above immediately.\n", file=sys.stderr)

def categorize_violations(violations, filepath):
    """Categorize violations by type."""
    result = {
        'nesting': [],
        'long_lines': [],
        'long_functions': [],
        'long_files': []
    }
    
    for v in violations:
        if "nesting depth" in v:
            result['nesting'].append((filepath, v))
        elif "characters long" in v:
            result['long_lines'].append((filepath, v))
        elif "Function" in v and "lines long" in v:
            result['long_functions'].append((filepath, v))
        elif "File is" in v and "lines long" in v:
            result['long_files'].append((filepath, v))
    
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

def handle_stop_event():
    """Handle Stop event."""
    # Check all Python files recursively
    python_files = glob.glob('**/*.py', recursive=True)
    
    # Group violations by type
    all_violations = {
        'nesting': [],
        'long_lines': [],
        'long_functions': [],
        'long_files': []
    }
    
    for filepath in python_files:
        violations = validate_file(filepath)
        if violations:
            cats = categorize_violations(violations, filepath)
            for key in all_violations:
                all_violations[key].extend(cats[key])
    
    # Check if any violations exist
    has_violations = any(all_violations.values())
    
    if has_violations:
        msg_lines = ["Code quality issues found:", ""]
        
        # Add each violation type
        if all_violations['nesting']:
            msg_lines.extend(format_violation_group(
                "❌ EXCESSIVE NESTING (max: 3)",
                "Extract nested logic into separate functions "
                "or use early returns",
                all_violations['nesting']
            ))
        
        if all_violations['long_lines']:
            msg_lines.extend(format_violation_group(
                "❌ LONG LINES (max: 100 chars)",
                "Break lines using parentheses or line continuation",
                all_violations['long_lines']
            ))
        
        if all_violations['long_functions']:
            msg_lines.extend(format_violation_group(
                "❌ LONG FUNCTIONS (max: 30 lines)",
                "Split into smaller helper functions. "
                "Extract logical sections.",
                all_violations['long_functions']
            ))
        
        if all_violations['long_files']:
            msg_lines.extend(format_violation_group(
                "❌ LONG FILES (max: 200 lines)",
                "Split into multiple modules "
                "(e.g., validators.py, handlers.py)",
                all_violations['long_files']
            ))
        
        msg_lines.append("ACTION REQUIRED: Fix all violations above to proceed.")
        
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