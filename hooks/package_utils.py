#!/usr/bin/env python3
"""Package utilities for the package age checker."""

import re
import urllib.request
import json
import sys
from datetime import datetime, timezone

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

def get_package_publish_date(package_info, version):
    """Get the publish date for a specific package version."""
    if version == 'latest':
        version = package_info.get('dist-tags', {}).get('latest', '')
    
    publish_time = package_info.get('time', {}).get(version)
    if not publish_time:
        return None
        
    return datetime.fromisoformat(publish_time.replace('Z', '+00:00'))

def get_latest_version_info(package_info, current_version):
    """Get information about the latest version if different from current."""
    latest_version = package_info.get('dist-tags', {}).get('latest', '')
    if not latest_version or latest_version == current_version:
        return None, None
        
    latest_time = package_info.get('time', {}).get(latest_version)
    if not latest_time:
        return latest_version, None
        
    latest_date = datetime.fromisoformat(latest_time.replace('Z', '+00:00'))
    latest_age_days = (datetime.now(timezone.utc) - latest_date).days
    return latest_version, latest_age_days

def extract_packages_from_command(command):
    """Extract package specifications from npm/yarn commands."""
    patterns = [
        r'(?:npm|yarn)\s+(?:install|add|i)\s+(.+)',
        r'(?:npm|yarn)\s+(?:install|add|i)\s+--[a-zA-Z-]+\s+(.+)',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, command)
        if not match:
            continue
            
        packages_str = match.group(1)
        # Remove flags
        packages_str = re.sub(r'--\S+', '', packages_str).strip()
        # Split by spaces
        return [p for p in packages_str.split() if p and not p.startswith('-')]
    
    return []

def log_to_stderr(message):
    """Log to stderr for debugging."""
    print(message, file=sys.stderr)

def parse_hook_input():
    """Parse and validate hook input."""
    input_text = sys.stdin.read()
    
    try:
        return json.loads(input_text)
    except json.JSONDecodeError:
        log_to_stderr("Failed to parse input JSON")
        return None