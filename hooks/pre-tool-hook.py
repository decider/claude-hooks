#!/usr/bin/env python3
"""Direct PreToolUse Hook Handler - Analyzes code BEFORE Write/Edit/MultiEdit operations."""

import json
import sys
import re

def check_js_quality(lines):
    """Check JavaScript/TypeScript code quality."""
    for line in lines:
        # Check for deep nesting (8+ spaces)
        if re.match(r'^\s{8}', line):
            return False, "Deep nesting detected. Please refactor to reduce nesting levels."
        
        # Check for long lines
        if len(line) > 100:
            return False, "Lines exceed 100 characters. Please break long lines."
    return True, None

def check_python_quality(lines):
    """Check Python code quality."""
    for line in lines:
        is_valid, msg = check_python_indentation(line)
        if not is_valid:
            return False, msg
    return True, None

def check_ruby_quality(lines):
    """Check Ruby code quality."""
    for line in lines:
        is_valid, msg = check_ruby_indentation(line)
        if not is_valid:
            return False, msg
    return True, None

def check_python_indentation(line):
    """Check Python line indentation."""
    if not line or line.startswith('#'):
        return True, None
        
    match = re.match(r'^(\s+)', line)
    if not match:
        return True, None
        
    indent_len = len(match.group(1))
    if indent_len % 4 != 0:
        msg = "Python indentation should be 4 spaces (PEP8). Found inconsistent indentation."
        return False, msg
    return True, None

def check_ruby_indentation(line):
    """Check Ruby line indentation."""
    if not line or line.startswith('#'):
        return True, None
        
    match = re.match(r'^(\s+)', line)
    if not match:
        return True, None
        
    indent_len = len(match.group(1))
    if indent_len % 2 != 0:
        msg = "Ruby indentation should be 2 spaces. Found inconsistent indentation."
        return False, msg
    return True, None

def check_content_quality(content, file_ext):
    """Check content quality based on file type."""
    lines = content.split('\n')
    
    if file_ext in ['ts', 'tsx', 'js', 'jsx']:
        return check_js_quality(lines)
    
    if file_ext == 'py':
        return check_python_quality(lines)
    
    if file_ext == 'rb':
        return check_ruby_quality(lines)
    
    return True, None

def parse_input():
    """Parse and validate input."""
    try:
        return json.loads(sys.stdin.read())
    except:
        return None

def is_valid_event(input_data):
    """Check if this is a valid event to process."""
    hook_event = input_data.get('hook_event_name', '')
    if hook_event != 'PreToolUse':
        return False
    
    tool_name = input_data.get('tool_name', '')
    if tool_name not in ['Write', 'Edit', 'MultiEdit']:
        return False
    
    return True

def get_file_extension(file_path):
    """Extract file extension."""
    if not file_path or '.' not in file_path:
        return ''
    return file_path.split('.')[-1]

def should_skip_file(ext):
    """Check if file type should be skipped."""
    skip_extensions = ['md', 'txt', 'json', 'yml', 'yaml', 'xml', 'html', 'css']
    return ext in skip_extensions

def extract_content(tool_name, tool_input):
    """Extract content based on tool type."""
    if tool_name == 'Write':
        return tool_input.get('content', '')
    if tool_name == 'Edit':
        return tool_input.get('new_string', '')
    return None

def check_multi_edit_content(edits, ext):
    """Check MultiEdit content quality."""
    for edit in edits:
        new_string = edit.get('new_string', '')
        if not new_string:
            continue
            
        is_valid, reason = check_content_quality(new_string, ext)
        if not is_valid:
            print(f"⚠️  Code quality suggestion: {reason}", file=sys.stderr)

def process_tool_content(input_data, tool_input, ext):
    """Process tool content based on tool type."""
    tool_name = input_data.get('tool_name', '')
    
    if tool_name == 'MultiEdit':
        edits = tool_input.get('edits', [])
        check_multi_edit_content(edits, ext)
        return
    
    # Handle Write/Edit
    content = extract_content(tool_name, tool_input)
    if not content:
        return
    
    is_valid, reason = check_content_quality(content, ext)
    if not is_valid:
        print(f"⚠️  Code quality suggestion: {reason}", file=sys.stderr)

def main():
    """Main entry point."""
    input_data = parse_input()
    if not input_data or not is_valid_event(input_data):
        sys.exit(0)
    
    tool_input = input_data.get('tool_input', {})
    file_path = tool_input.get('file_path', '')
    if not file_path:
        sys.exit(0)
    
    ext = get_file_extension(file_path)
    if should_skip_file(ext):
        sys.exit(0)
    
    process_tool_content(input_data, tool_input, ext)
    sys.exit(0)

if __name__ == '__main__':
    main()