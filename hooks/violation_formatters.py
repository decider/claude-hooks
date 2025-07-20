#!/usr/bin/env python3
"""Violation message formatting utilities."""

import sys


def format_simple_violations(violations, msg_lines):
    """Format violations that don't need truncation."""
    if violations:
        msg_lines.extend([f"  {v}" for v in violations])
        msg_lines.append("")


def format_truncated_violations(violations, filepath, violation_type, max_count):
    """Format violations with truncation for long lists."""
    msg_lines = []
    if violations:
        msg_lines.append(f"{violation_type} violations in {filepath}:")
        for i, v in enumerate(violations):
            if i < max_count:
                msg_lines.append(f"  {v}")
        if len(violations) > max_count:
            msg_lines.append(f"  ... and {len(violations) - max_count} more")
        msg_lines.append("")
    return msg_lines


def build_pre_tool_violation_message(violations, filepath):
    """Build detailed violation message for PreToolUse."""
    msg_lines = [f"Code quality violations in {filepath}:", ""]
    
    format_simple_violations(violations['file_length'], msg_lines)
    
    msg_lines.extend(format_truncated_violations(
        violations['line_length'], filepath, "Line length", 5))
    
    if violations['function_length']:
        msg_lines.append(f"Function length violations in {filepath}:")
        format_simple_violations(violations['function_length'], msg_lines)
    
    msg_lines.extend(format_truncated_violations(
        violations['nesting_depth'], filepath, "Nesting depth", 3))
    
    msg_lines.append("Fix these violations before proceeding.")
    return "\n".join(msg_lines)


def print_violations_to_stderr(violations, filepath, violation_type, max_count):
    """Print violations to stderr with truncation."""
    if violations:
        print(f"\n{violation_type} violations in {filepath}:", file=sys.stderr)
        for i, v in enumerate(violations):
            if i < max_count:
                print(f"  {v}", file=sys.stderr)
        if len(violations) > max_count:
            print(f"  ... and {len(violations) - max_count} more", file=sys.stderr)


def print_post_tool_violations(violations, filepath):
    """Print detailed violations for PostToolUse to stderr."""
    print(f"\n⚠️  Code quality issues in {filepath}:\n", file=sys.stderr)
    
    if violations['file_length']:
        for v in violations['file_length']:
            print(f"  {v}", file=sys.stderr)
    
    print_violations_to_stderr(violations['line_length'], filepath, "Line length", 5)
    
    if violations['function_length']:
        print(f"\nFunction length violations in {filepath}:", file=sys.stderr)
        for v in violations['function_length']:
            print(f"  {v}", file=sys.stderr)
    
    print_violations_to_stderr(violations['nesting_depth'], filepath, "Nesting depth", 3)
    
    print("\n🚨 YOU WILL BE BLOCKED at session end if these aren't fixed!", file=sys.stderr)
    print("   FIX NOW: Address the issues above immediately.\n", file=sys.stderr)