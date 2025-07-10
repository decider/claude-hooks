#!/bin/bash

# Claude Code Hook: Task Completion Notifications
# Sends notifications when Claude completes certain tasks

# Parse input from Claude
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool // empty')
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
    
    # Try loading from various .env files
    for env_file in \
        ".env" \
        ".claude/pushover.env" \
        "$HOME/.claude/pushover.env"; do
        if [ -f "$env_file" ]; then
            # Safely source the env file
            set -a
            source "$env_file" 2>/dev/null
            set +a
        fi
    done
    
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
        # Silently skip if not configured
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
    
    # Send platform-specific notification first
    case "$(uname -s)" in
        Darwin*)
            send_macos_notification "$title" "$message" "Glass"
            ;;
        Linux*)
            send_linux_notification "$title" "$message"
            ;;
        *)
            send_terminal_notification
            ;;
    esac
    
    # Also send Pushover notification if configured
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

# Check tool-specific triggers
case "$TOOL" in
    "Write"|"Edit"|"MultiEdit")
        if [ -n "$FILE_PATH" ]; then
            notification_title="File Modified"
            notification_message="Updated: $(basename "$FILE_PATH")"
            should_notify=true
        fi
        ;;
    
    "Bash")
        # Check for specific commands
        if [[ "$COMMAND" =~ git[[:space:]]+(commit|push) ]]; then
            notification_title="Git Operation"
            notification_message="Completed: $COMMAND"
            should_notify=true
            # Higher priority for push operations
            if [[ "$COMMAND" =~ git[[:space:]]push ]]; then
                notification_priority=1
            fi
        elif [[ "$COMMAND" =~ (npm|yarn)[[:space:]]+(run[[:space:]]+(build|test)|test) ]]; then
            notification_title="Build/Test Complete"
            notification_message="Finished: $COMMAND"
            should_notify=true
            # Higher priority for build/test operations
            notification_priority=1
        elif [[ "$COMMAND" =~ anchor[[:space:]]+(build|test|deploy) ]]; then
            notification_title="Anchor Operation"
            notification_message="Completed: $COMMAND"
            should_notify=true
            # Highest priority for deploy operations
            if [[ "$COMMAND" =~ deploy ]]; then
                notification_priority=2
            else
                notification_priority=1
            fi
        fi
        ;;
    
    "TodoWrite")
        # Check if todos are being marked as completed
        if echo "$INPUT" | jq -e '.tool_input.todos[] | select(.status == "completed")' > /dev/null 2>&1; then
            completed_count=$(echo "$INPUT" | jq '[.tool_input.todos[] | select(.status == "completed")] | length')
            notification_title="Tasks Completed"
            notification_message="Marked $completed_count task(s) as complete"
            should_notify=true
        fi
        ;;
esac

# Special notification for stop event (when Claude finishes)
if [ "$TOOL" = "stop" ] || [ "$1" = "stop" ]; then
    notification_title="Claude Code Finished"
    notification_message="All tasks completed"
    should_notify=true
fi

# Send notification if triggered
if [ "$should_notify" = true ] && [ -n "$notification_title" ]; then
    send_notification "$notification_title" "$notification_message" "$notification_priority"
    
    # Log to file for debugging (optional)
    if [ -n "$CLAUDE_HOOK_LOG" ]; then
        echo "[$(date)] $notification_title: $notification_message (priority=$notification_priority)" >> "$CLAUDE_HOOK_LOG"
    fi
fi

# Always pass through the input
echo "$INPUT"
exit 0