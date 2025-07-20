#!/usr/bin/env python3
"""Claude Code Hook: Task Completion Notifications."""

import json
import sys
import os

from notification_utils import (
    log_to_stderr,
    load_pushover_config,
    send_notification
)


def parse_input_data():
    """Parse input data from stdin."""
    try:
        return json.loads(sys.stdin.read())
    except:
        return None


def handle_stop_event(input_data):
    """Handle Stop event."""
    event_name = input_data.get('hook_event_name', '')
    tool = input_data.get('tool', '') or input_data.get('tool_name', '')
    
    if event_name != 'Stop' and tool != 'stop':
        return
        
    project_name = os.path.basename(os.getcwd())
    
    # Check if Pushover is configured
    if not load_pushover_config():
        log_to_stderr("💡 Want notifications when Claude finishes? Set up Pushover:")
        log_to_stderr("   1. Get the app: https://pushover.net/clients")
        log_to_stderr("   2. Add to .env: PUSHOVER_USER_KEY=... and PUSHOVER_APP_TOKEN=...")
        return
        
    send_notification(
        "Claude Code Finished",
        f"All tasks completed in {project_name}",
        priority=2  # High priority for completion
    )


def main():
    """Main entry point."""
    input_data = parse_input_data()
    if not input_data:
        print(json.dumps({"action": "continue"}))
        return
    
    handle_stop_event(input_data)
    
    # Always continue
    print(json.dumps({"action": "continue"}))


if __name__ == '__main__':
    main()