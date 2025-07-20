#!/usr/bin/env python3
"""Claude Code Hook: Prevent installation of outdated packages."""

import json
import sys
import re
from datetime import datetime
import os

from package_utils import (
    parse_package_spec,
    is_npm_package,
    fetch_package_info,
    get_package_publish_date,
    get_latest_version_info,
    extract_packages_from_command,
    log_to_stderr,
    parse_hook_input
)

# Configuration
MAX_AGE_DAYS = int(os.environ.get('MAX_AGE_DAYS', '180'))  # Default: 6 months
TEST_MODE = os.environ.get('CLAUDE_HOOKS_TEST_MODE', '0') == '1'

def handle_test_mode(package_spec):
    """Handle test mode logic."""
    if package_spec not in ['left-pad@1.0.0', 'moment@2.18.0']:
        return True, None
    error_msg = f"Package {package_spec} is too old (test mode simulation)."
    log_to_stderr(error_msg)
    return False, error_msg

def build_age_error_message(package_name, version, age_days, package_info):
    """Build error message for old package."""
    error_msg = (
        f"Package {package_name}@{version} is too old "
        f"(published {age_days} days ago, max allowed: {MAX_AGE_DAYS} days)."
    )
    
    # Add latest version info if available
    latest_version, latest_age_days = get_latest_version_info(package_info, version)
    if latest_version and latest_age_days is not None:
        error_msg += (
            f" Latest version is {latest_version} "
            f"({latest_age_days} days old)."
        )
    
    return error_msg

def check_package_validity(package_info, package_name, version):
    """Check if package info is valid and get publish date."""
    if not package_info:
        log_to_stderr(f"Could not fetch info for {package_name}")
        return None, True  # Allow if we can't verify
        
    publish_date = get_package_publish_date(package_info, version)
    if not publish_date:
        log_to_stderr(f"No publish time found for {package_name}@{version}")
        return None, True
        
    return publish_date, False

def log_package_age(package_name, version, age_days):
    """Log package age information."""
    log_to_stderr(
        f"Package {package_name}@{version} is {age_days} days old "
        f"(within {MAX_AGE_DAYS} day limit)"
    )

def process_package_age(package_name, version, package_info):
    """Process package age and return result."""
    publish_date, should_allow = check_package_validity(
        package_info, package_name, version
    )
    
    if should_allow:
        return True, None
    
    # Calculate age
    age_days = (datetime.now() - publish_date).days
    
    if age_days <= MAX_AGE_DAYS:
        log_package_age(package_name, version, age_days)
        return True, None
        
    # Package is too old
    error_msg = build_age_error_message(
        package_name, version, age_days, package_info
    )
    log_to_stderr(error_msg)
    return False, error_msg

def check_package_age(package_spec):
    """Check if a package is too old."""
    package_name, version = parse_package_spec(package_spec)
    
    # Skip non-npm packages
    if not is_npm_package(package_spec):
        return True, None
    
    # Test mode simulation
    if TEST_MODE:
        return handle_test_mode(package_spec)
    
    try:
        package_info = fetch_package_info(package_name)
        return process_package_age(package_name, version, package_info)
    except Exception as e:
        log_to_stderr(f"Error checking {package_name}: {str(e)}")
        return True, None  # Allow if error

def check_packages_in_command(command):
    """Check all packages in an npm/yarn command."""
    packages = extract_packages_from_command(command)
    if not packages:
        log_to_stderr("No packages specified, checking package.json")
        return []
        
    failed_packages = []
    for package in packages:
        is_allowed, error_msg = check_package_age(package)
        if not is_allowed:
            failed_packages.append((package, error_msg))
            
    return failed_packages

def block_old_packages(error_messages):
    """Block installation of old packages."""
    block_reason = (
        "One or more packages are too old. Please use newer versions "
        "or add them to the allowlist if absolutely necessary."
    )
    
    if TEST_MODE:
        log_to_stderr("[TEST MODE] Would have blocked")
        print(json.dumps({"action": "continue"}))
    else:
        print(block_reason + "\n\n" + "\n".join(error_messages), file=sys.stderr)
        sys.exit(2)  # Exit code 2 blocks the operation

def handle_package_installation(input_data):
    """Handle package installation commands."""
    command = input_data.get('tool_input', {}).get('command', '')
    if not command:
        return
        
    # Check if this is an install command
    if not re.match(r'(npm|yarn)\s+(install|add|i)', command):
        return
        
    log_to_stderr(f"Checking packages in command: {command}")
    
    # Check packages
    failed_packages = check_packages_in_command(command)
    if not failed_packages:
        return
        
    # Block if any packages are too old
    error_messages = [msg for _, msg in failed_packages if msg]
    block_old_packages(error_messages)

def handle_package_json_edit(input_data):
    """Handle package.json edits."""
    command = input_data.get('tool_input', {}).get('command', '')
    tool_input = input_data.get('tool_input', {})
    description = tool_input.get('description', '')
    
    if 'package.json' in command or 'package.json' in description:
        log_to_stderr(
            "Notice: package.json edit detected. "
            "Ensure dependencies are up to date."
        )

def main():
    """Main entry point."""
    input_data = parse_hook_input()
    if not input_data:
        print(json.dumps({"action": "continue"}))
        return
    
    # Only process Bash tool
    if input_data.get('tool_name', '') != 'Bash':
        print(json.dumps({"action": "continue"}))
        return
    
    # Handle package installation
    handle_package_installation(input_data)
    
    # Check for package.json edits
    handle_package_json_edit(input_data)
    
    # Allow the command to proceed
    print(json.dumps({"action": "continue"}))

if __name__ == '__main__':
    main()