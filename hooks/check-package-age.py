#!/usr/bin/env python3
"""Claude Code Hook: Prevent installation of outdated packages."""

import json
import sys
import re
import urllib.request
import urllib.error
from datetime import datetime, timedelta
import os

# Configuration
MAX_AGE_DAYS = int(os.environ.get('MAX_AGE_DAYS', '180'))  # Default: 6 months
TEST_MODE = os.environ.get('CLAUDE_HOOKS_TEST_MODE', '0') == '1'

def log_to_stderr(message):
    """Log to stderr for debugging."""
    print(message, file=sys.stderr)

def parse_package_spec(package_spec):
    """Parse package@version into name and version."""
    match = re.match(r'^([^@]+)@(.+)$', package_spec)
    if match:
        return match.group(1), match.group(2)
    return package_spec, 'latest'

def is_npm_package(package_spec):
    """Check if this is an npm package (not local/git/etc)."""
    if re.match(r'^(\.|\/|git\+|http|file:)', package_spec):
        return False
    return True

def fetch_package_info(package_name):
    """Fetch package info from npm registry."""
    url = f'https://registry.npmjs.org/{package_name}'
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            return json.loads(response.read().decode('utf-8'))
    except:
        return None

def check_package_age(package_spec):
    """Check if a package is too old."""
    package_name, version = parse_package_spec(package_spec)
    
    # Skip non-npm packages
    if not is_npm_package(package_spec):
        return True, None
    
    # Test mode simulation
    if TEST_MODE and package_spec in ['left-pad@1.0.0', 'moment@2.18.0']:
        error_msg = f"Package {package_spec} is too old (test mode simulation)."
        log_to_stderr(error_msg)
        return False, error_msg
    
    # Fetch package info
    package_info = fetch_package_info(package_name)
    if not package_info:
        log_to_stderr(f"Could not fetch package info for {package_name}, allowing installation")
        return True, None
    
    # Get publish time
    try:
        if version == 'latest':
            latest_version = package_info.get('dist-tags', {}).get('latest')
            if latest_version:
                publish_time = package_info.get('time', {}).get(latest_version)
                version = latest_version
            else:
                return True, None
        else:
            publish_time = package_info.get('time', {}).get(version)
        
        if not publish_time:
            return True, None
        
        # Parse publish date
        publish_date = datetime.fromisoformat(publish_time.replace('Z', '+00:00'))
        age_days = (datetime.now() - publish_date).days
        
        if age_days > MAX_AGE_DAYS:
            # Get latest version info
            latest_version = package_info.get('dist-tags', {}).get('latest', '')
            error_msg = f"Package {package_name}@{version} is too old (published {age_days} days ago, max allowed: {MAX_AGE_DAYS} days)."
            
            if latest_version and latest_version != version:
                latest_time = package_info.get('time', {}).get(latest_version)
                if latest_time:
                    latest_date = datetime.fromisoformat(latest_time.replace('Z', '+00:00'))
                    latest_age_days = (datetime.now() - latest_date).days
                    error_msg += f" Latest version is {latest_version} ({latest_age_days} days old)."
            
            log_to_stderr(error_msg)
            return False, error_msg
        
        log_to_stderr(f"Package {package_name}@{version} is {age_days} days old (within {MAX_AGE_DAYS} day limit)")
        return True, None
        
    except Exception as e:
        # If we can't parse dates, allow installation
        return True, None

def extract_packages_from_command(command):
    """Extract package names from npm/yarn commands."""
    packages = []
    
    # Remove command prefix
    cmd_without_prefix = re.sub(r'^(npm (install|i)|yarn add)\s*', '', command)
    
    # Split by spaces and filter out flags
    tokens = cmd_without_prefix.split()
    for token in tokens:
        if token and not token.startswith('-'):
            packages.append(token)
    
    return packages

def main():
    """Main entry point."""
    # Read input from stdin
    try:
        input_data = json.loads(sys.stdin.read())
    except:
        # Invalid JSON, continue
        print(json.dumps({"action": "continue"}))
        return
    
    # Only process PreToolUse events for Bash tools
    hook_event = input_data.get('hook_event_name', '')
    if hook_event != 'PreToolUse':
        print(json.dumps({"action": "continue"}))
        return
    
    tool_name = input_data.get('tool_name', '')
    if tool_name != 'Bash':
        print(json.dumps({"action": "continue"}))
        return
    
    command = input_data.get('tool_input', {}).get('command', '')
    
    # Check if this is an npm/yarn install command
    if re.match(r'^npm\s+(install|i)\s+|^yarn\s+add\s+', command):
        packages = extract_packages_from_command(command)
        
        if packages:
            log_to_stderr(f"Checking {len(packages)} package(s) for age compliance")
            
            failed_packages = []
            error_messages = []
            
            for pkg in packages:
                is_valid, error_msg = check_package_age(pkg)
                if not is_valid:
                    failed_packages.append(pkg)
                    if error_msg:
                        error_messages.append(error_msg)
            
            if failed_packages:
                block_reason = "One or more packages are too old. Please use newer versions or add them to the allowlist if absolutely necessary."
                
                # In test mode, don't actually block
                if TEST_MODE:
                    log_to_stderr("[TEST MODE] Would have blocked")
                    print(json.dumps({"action": "continue"}))
                else:
                    print(block_reason + "\n\n" + "\n".join(error_messages), file=sys.stderr)
                    sys.exit(2)  # Exit code 2 blocks the operation
                return
    
    # Check if editing package.json
    if 'package.json' in command or 'package.json' in input_data.get('tool_input', {}).get('description', ''):
        log_to_stderr("Notice: package.json edit detected. Ensure dependencies are up to date.")
    
    # Allow the command to proceed
    print(json.dumps({"action": "continue"}))

if __name__ == '__main__':
    main()