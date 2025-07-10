#!/bin/bash

# Claude Code Hook: Task Completion Notifications
# Sends notifications when Claude completes certain tasks

# Enable debug logging if .env has it set
if [ -f ".env" ] && grep -q "CLAUDE_HOOK_LOG=" ".env" 2>/dev/null; then
    export $(grep "CLAUDE_HOOK_LOG=" ".env" | xargs)
fi

# Debug: Log execution context
if [ -n "$CLAUDE_HOOK_LOG" ]; then
    echo "[$(date)] Hook executing in directory: $PWD" >> "$CLAUDE_HOOK_LOG"
    echo "[$(date)] Environment has PUSHOVER keys: USER=$([ -n "$PUSHOVER_USER_KEY" ] && echo "YES" || echo "NO"), APP=$([ -n "$PUSHOVER_APP_TOKEN" ] && echo "YES" || echo "NO")" >> "$CLAUDE_HOOK_LOG"
fi

# Parse input from Claude
INPUT=$(cat)

# Debug: Log raw input
if [ -n "$CLAUDE_HOOK_LOG" ]; then
    echo "[$(date)] Raw input: $INPUT" >> "$CLAUDE_HOOK_LOG"
fi

# Try both old and new formats for compatibility
TOOL=$(echo "$INPUT" | jq -r '.tool // .tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // empty')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Function to send macOS notification
send_macos_notification() {
    local title="$1"
    local message="$2"
    local sound="${3:-default}"
    
    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"$message\" with title \"Claude Code\" subtitle \"$title\" sound name \"$sound\""
    fi
}

# Function to send Linux notification
send_linux_notification() {
    local title="$1"
    local message="$2"
    
    if command -v notify-send &> /dev/null; then
        notify-send "Claude Code: $title" "$message" --icon=dialog-information
    fi
}

# Function to send terminal bell/beep
send_terminal_notification() {
    printf '\a'
}

# Load Pushover configuration from multiple sources
load_pushover_config() {
    # Check if already configured via environment
    if [ -n "$PUSHOVER_USER_KEY" ] && [ -n "$PUSHOVER_APP_TOKEN" ]; then
        return 0
    fi
    
    # Get the actual working directory where Claude is running
    local working_dir="${PWD:-$(pwd)}"
    
    # Try loading from various .env files
    for env_file in \
        "$working_dir/.env" \
        "$working_dir/.claude/pushover.env" \
        ".env" \
        ".claude/pushover.env" \
        "$HOME/.claude/pushover.env"; do
        if [ -f "$env_file" ]; then
            # Debug logging
            if [ -n "$CLAUDE_HOOK_LOG" ]; then
                echo "[$(date)] Attempting to load env from: $env_file" >> "$CLAUDE_HOOK_LOG"
            fi
            # Safely source the env file
            set -a
            source "$env_file" 2>/dev/null
            set +a
            # Check if keys were loaded
            if [ -n "$PUSHOVER_USER_KEY" ] && [ -n "$PUSHOVER_APP_TOKEN" ]; then
                if [ -n "$CLAUDE_HOOK_LOG" ]; then
                    echo "[$(date)] Successfully loaded Pushover keys from: $env_file" >> "$CLAUDE_HOOK_LOG"
                fi
                return 0
            fi
        fi
    done
    
    # Log failure to find keys
    if [ -n "$CLAUDE_HOOK_LOG" ]; then
        echo "[$(date)] Failed to load Pushover keys from any .env file" >> "$CLAUDE_HOOK_LOG"
    fi
    
    # Return success if we have both keys
    [ -n "$PUSHOVER_USER_KEY" ] && [ -n "$PUSHOVER_APP_TOKEN" ]
}

# Function to send Pushover notification
send_pushover_notification() {
    local title="$1"
    local message="$2"
    local priority="${3:-1}"  # Default: normal priority
    
    # Load configuration
    if ! load_pushover_config; then
        # Output helpful message to stderr (will be shown to user)
        echo "⚠️  Pushover notification skipped - API keys not configured" >&2
        echo "To enable Pushover notifications:" >&2
        echo "1. Get Pushover app (\$5): https://pushover.net/clients" >&2
        echo "2. Create an app: https://pushover.net/apps/build" >&2
        echo "3. Add to your project's .env file:" >&2
        echo "   PUSHOVER_USER_KEY=your_user_key" >&2
        echo "   PUSHOVER_APP_TOKEN=your_app_token" >&2
        return 0
    fi
    
    # Determine project name for context
    local project_name=$(basename "$PWD")
    
    # Build curl command
    local curl_cmd="curl -s --form-string \"token=$PUSHOVER_APP_TOKEN\" \
         --form-string \"user=$PUSHOVER_USER_KEY\" \
         --form-string \"title=Claude Code: $project_name\" \
         --form-string \"message=$title - $message\" \
         --form-string \"priority=$priority\""
    
    # Add retry/expire for emergency priority
    if [ "$priority" = "2" ]; then
        curl_cmd="$curl_cmd --form-string \"retry=30\" --form-string \"expire=300\""
    fi
    
    # Send notification
    eval "$curl_cmd https://api.pushover.net/1/messages.json" > /dev/null 2>&1
    
    # Log if debugging enabled
    if [ -n "$CLAUDE_HOOK_LOG" ]; then
        echo "[$(date)] Pushover sent: $title - $message (priority=$priority)" >> "$CLAUDE_HOOK_LOG"
    fi
}

# Detect platform and send appropriate notification
send_notification() {
    local title="$1"
    local message="$2"
    local priority="${3:-1}"  # Default priority
    
    # Only send Pushover notification (no platform-specific notifications)
    send_pushover_notification "$title" "$message" "$priority"
}

# Track task completions
NOTIFY_TRIGGERS=(
    # File operations
    "created file"
    "updated file"
    "deleted file"
    
    # Git operations
    "git commit"
    "git push"
    "created PR"
    
    # Build/test operations
    "npm run build"
    "npm test"
    "anchor build"
    "anchor test"
    
    # Installation operations
    "npm install"
    "yarn add"
)

# Check if this is a task worth notifying about
should_notify=false
notification_title=""
notification_message=""
notification_priority=1  # Default: normal priority

# Check if this is a Stop event (when Claude finishes)
EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
if [ "$EVENT_NAME" = "Stop" ] || [ "$TOOL" = "stop" ] || [ "$1" = "stop" ]; then
    notification_title="Claude Code Finished"
    notification_message="All tasks completed in $(basename "$PWD")"
    should_notify=true
    notification_priority=2  # High priority for completion
fi

# Debug logging
if [ -n "$CLAUDE_HOOK_LOG" ]; then
    echo "[$(date)] Tool: $TOOL, Should notify: $should_notify, Title: $notification_title" >> "$CLAUDE_HOOK_LOG"
fi

# Send notification if triggered
if [ "$should_notify" = true ] && [ -n "$notification_title" ]; then
    # For Stop events, check if Pushover is configured before calling send_notification
    if [ "$EVENT_NAME" = "Stop" ] && ! load_pushover_config; then
        echo "💡 Want notifications when Claude finishes? Set up Pushover:" >&2
        echo "   1. Get the app: https://pushover.net/clients" >&2
        echo "   2. Add to .env: PUSHOVER_USER_KEY=... and PUSHOVER_APP_TOKEN=..." >&2
    else
        send_notification "$notification_title" "$notification_message" "$notification_priority"
    fi
    
    # Log to file for debugging (optional)
    if [ -n "$CLAUDE_HOOK_LOG" ]; then
        echo "[$(date)] $notification_title: $notification_message (priority=$notification_priority)" >> "$CLAUDE_HOOK_LOG"
    fi
fi

# Always pass through the input
echo "$INPUT"
exit 0