#!/usr/bin/env python3
"""Claude Code Hook: Task Completion Notifications."""

import json
import sys
import os
import subprocess
import urllib.request
import urllib.parse
from pathlib import Path

def log_to_stderr(message):
    """Log to stderr for user visibility."""
    print(message, file=sys.stderr)

def load_env_file(filepath):
    """Load environment variables from a file."""
    if not os.path.exists(filepath):
        return False
    
    loaded = False
    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    # Remove quotes if present
                    value = value.strip().strip('"').strip("'")
                    os.environ[key] = value
                    if key in ['PUSHOVER_USER_KEY', 'PUSHOVER_APP_TOKEN']:
                        loaded = True
    except:
        pass
    return loaded

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

def send_pushover_notification(title, message, priority=1):
    """Send notification via Pushover API."""
    if not load_pushover_config():
        # Output helpful message
        log_to_stderr("⚠️  Pushover notification skipped - API keys not configured")
        log_to_stderr("To enable Pushover notifications:")
        log_to_stderr("1. Get Pushover app ($5): https://pushover.net/clients")
        log_to_stderr("2. Create an app: https://pushover.net/apps/build")
        log_to_stderr("3. Add to your project's .env file:")
        log_to_stderr("   PUSHOVER_USER_KEY=your_user_key")
        log_to_stderr("   PUSHOVER_APP_TOKEN=your_app_token")
        return
    
    # Get project name for context
    project_name = os.path.basename(os.getcwd())
    
    # Build notification data
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
        script = f'''display notification "{message}" with title "Claude Code" subtitle "{title}" sound name "{sound}"'''
        subprocess.run(['osascript', '-e', script], capture_output=True)
    except:
        pass

def send_linux_notification(title, message):
    """Send Linux notification using notify-send."""
    try:
        subprocess.run(['notify-send', f'Claude Code: {title}', message, '--icon=dialog-information'], capture_output=True)
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

def main():
    """Main entry point."""
    # Read input from stdin
    try:
        input_data = json.loads(sys.stdin.read())
    except:
        # Invalid JSON, pass through
        print(json.dumps({"action": "continue"}))
        return
    
    # Check if this is a Stop event
    event_name = input_data.get('hook_event_name', '')
    tool = input_data.get('tool', '') or input_data.get('tool_name', '')
    
    if event_name == 'Stop' or tool == 'stop':
        project_name = os.path.basename(os.getcwd())
        
        # Check if Pushover is configured
        if not load_pushover_config():
            log_to_stderr("💡 Want notifications when Claude finishes? Set up Pushover:")
            log_to_stderr("   1. Get the app: https://pushover.net/clients")
            log_to_stderr("   2. Add to .env: PUSHOVER_USER_KEY=... and PUSHOVER_APP_TOKEN=...")
        else:
            send_notification(
                "Claude Code Finished",
                f"All tasks completed in {project_name}",
                priority=2  # High priority for completion
            )
    
    # Always continue
    print(json.dumps({"action": "continue"}))

if __name__ == '__main__':
    main()