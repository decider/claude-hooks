#!/usr/bin/env python3
"""Notification utilities for Claude Code hooks."""

import os
import subprocess
import urllib.request
import urllib.parse
import sys


def log_to_stderr(message):
    """Log to stderr for user visibility."""
    print(message, file=sys.stderr)


def parse_env_line(line):
    """Parse a single environment variable line."""
    line = line.strip()
    if not line or line.startswith('#') or '=' not in line:
        return None, None
    
    key, value = line.split('=', 1)
    # Remove quotes if present
    value = value.strip().strip('"').strip("'")
    return key, value


def process_env_lines(lines):
    """Process environment file lines."""
    loaded = False
    for line in lines:
        key, value = parse_env_line(line)
        if key is None:
            continue
            
        os.environ[key] = value
        if key in ['PUSHOVER_USER_KEY', 'PUSHOVER_APP_TOKEN']:
            loaded = True
    return loaded

def load_env_file(filepath):
    """Load environment variables from a file."""
    if not os.path.exists(filepath):
        return False
    
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
        return process_env_lines(lines)
    except:
        return False


def load_pushover_config():
    """Load Pushover configuration from various sources."""
    # Check if already configured
    if os.environ.get('PUSHOVER_USER_KEY') and os.environ.get('PUSHOVER_APP_TOKEN'):
        return True
    
    # Try loading from various .env files
    working_dir = os.getcwd()
    env_files = [
        os.path.join(working_dir, '.env'),
        os.path.join(working_dir, '.claude', 'pushover.env'),
        '.env',
        '.claude/pushover.env',
        os.path.expanduser('~/.claude/pushover.env')
    ]
    
    for env_file in env_files:
        if load_env_file(env_file):
            return True
    
    return bool(os.environ.get('PUSHOVER_USER_KEY') and os.environ.get('PUSHOVER_APP_TOKEN'))


def log_pushover_setup_instructions():
    """Log Pushover setup instructions."""
    log_to_stderr("⚠️  Pushover notification skipped - API keys not configured")
    log_to_stderr("To enable Pushover notifications:")
    log_to_stderr("1. Get Pushover app ($5): https://pushover.net/clients")
    log_to_stderr("2. Create an app: https://pushover.net/apps/build")
    log_to_stderr("3. Add to your project's .env file:")
    log_to_stderr("   PUSHOVER_USER_KEY=your_user_key")
    log_to_stderr("   PUSHOVER_APP_TOKEN=your_app_token")


def build_pushover_data(title, message, priority, project_name):
    """Build Pushover notification data."""
    data = {
        'token': os.environ['PUSHOVER_APP_TOKEN'],
        'user': os.environ['PUSHOVER_USER_KEY'],
        'title': f'Claude Code: {project_name}',
        'message': f'{title} - {message}',
        'priority': str(priority)
    }
    
    # Add retry/expire for emergency priority
    if priority == 2:
        data['retry'] = '30'
        data['expire'] = '300'
    
    return data


def send_pushover_notification(title, message, priority=1):
    """Send notification via Pushover API."""
    if not load_pushover_config():
        log_pushover_setup_instructions()
        return
    
    # Get project name for context
    project_name = os.path.basename(os.getcwd())
    
    # Build notification data
    data = build_pushover_data(title, message, priority, project_name)
    
    # Send notification
    try:
        req = urllib.request.Request(
            'https://api.pushover.net/1/messages.json',
            data=urllib.parse.urlencode(data).encode('utf-8')
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            response.read()
    except:
        pass


def send_macos_notification(title, message, sound='default'):
    """Send macOS notification using osascript."""
    try:
        script = (
            f'display notification "{message}" '
            f'with title "Claude Code" subtitle "{title}" '
            f'sound name "{sound}"'
        )
        subprocess.run(['osascript', '-e', script], capture_output=True)
    except:
        pass


def send_linux_notification(title, message):
    """Send Linux notification using notify-send."""
    try:
        subprocess.run([
            'notify-send', 
            f'Claude Code: {title}', 
            message, 
            '--icon=dialog-information'
        ], capture_output=True)
    except:
        pass


def send_notification(title, message, priority=1):
    """Send notification based on platform."""
    # Try Pushover first (works on all platforms)
    send_pushover_notification(title, message, priority)
    
    # Also try platform-specific notifications
    platform = sys.platform
    if platform == 'darwin':
        send_macos_notification(title, message)
    elif platform.startswith('linux'):
        send_linux_notification(title, message)