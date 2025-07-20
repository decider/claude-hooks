#!/usr/bin/env python3
"""Direct PreToolUse Hook Handler - Analyzes code BEFORE Write/Edit/MultiEdit operations."""

import json
import sys
import re

def check_content_quality(content, file_ext):
    """Check content quality based on file type."""
    lines = content.split('\n')
    
    if file_ext in ['ts', 'tsx', 'js', 'jsx']:
        # TypeScript/JavaScript checks
        for line in lines:
            # Check for deep nesting (8+ spaces)
            if re.match(r'^\s{8}', line):
                return False, "Deep nesting detected. Please refactor to reduce nesting levels."
            
            # Check for long lines
            if len(line) > 100:
                return False, "Lines exceed 100 characters. Please break long lines."
    
    elif file_ext == 'py':
        # Python checks
        for line in lines:
            # Check for non-standard indentation (not multiples of 4)
            if line and not line.startswith('#'):
                match = re.match(r'^(\s+)', line)
                if match:
                    indent_len = len(match.group(1))
                    if indent_len % 4 != 0:
                        return False, "Python indentation should be 4 spaces (PEP8). Found inconsistent indentation."
    
    elif file_ext == 'rb':
        # Ruby checks
        for line in lines:
            # Check for non-standard indentation (not multiples of 2)
            if line and not line.startswith('#'):
                match = re.match(r'^(\s+)', line)
                if match:
                    indent_len = len(match.group(1))
                    if indent_len % 2 != 0:
                        return False, "Ruby indentation should be 2 spaces. Found inconsistent indentation."
    
    return True, None

def main():
    """Main entry point."""
    # Read input from stdin
    try:
        input_data = json.loads(sys.stdin.read())
    except:
        # Invalid JSON, continue
        sys.exit(0)
    
    # Only process PreToolUse events
    hook_event = input_data.get('hook_event_name', '')
    if hook_event != 'PreToolUse':
        sys.exit(0)
    
    # Only process Write/Edit/MultiEdit tools
    tool_name = input_data.get('tool_name', '')
    if tool_name not in ['Write', 'Edit', 'MultiEdit']:
        sys.exit(0)
    
    # Extract file path
    tool_input = input_data.get('tool_input', {})
    file_path = tool_input.get('file_path', '')
    
    if not file_path:
        sys.exit(0)
    
    # Get file extension
    ext = file_path.split('.')[-1] if '.' in file_path else ''
    
    # Skip non-code files
    if ext in ['md', 'txt', 'json', 'yml', 'yaml', 'xml', 'html', 'css']:
        sys.exit(0)
    
    # Extract content
    content = None
    if tool_name == 'Write':
        content = tool_input.get('content', '')
    elif tool_name == 'Edit':
        content = tool_input.get('new_string', '')
    elif tool_name == 'MultiEdit':
        # For MultiEdit, check all new_strings
        edits = tool_input.get('edits', [])
        for edit in edits:
            new_string = edit.get('new_string', '')
            if new_string:
                is_valid, reason = check_content_quality(new_string, ext)
                if not is_valid:
                    # Use JSON format for blocking
                    print(json.dumps({
                        "decision": "block",
                        "reason": reason
                    }))
                    sys.exit(0)
        # If all edits pass, continue
        sys.exit(0)
    
    if not content:
        sys.exit(0)
    
    # Check content quality
    is_valid, reason = check_content_quality(content, ext)
    
    if not is_valid:
        # Use JSON format for blocking
        print(json.dumps({
            "decision": "block",
            "reason": reason
        }))
    else:
        # Continue normally
        sys.exit(0)

if __name__ == '__main__':
    main()