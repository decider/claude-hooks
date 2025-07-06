#!/bin/bash


# Source logging library
HOOK_NAME="task-completion-notify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Log hook start
log_hook_start "$HOOK_NAME" "Hook invoked"

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

# Detect platform and send appropriate notification
send_notification() {
    local title="$1"
    local message="$2"
    
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
        elif [[ "$COMMAND" =~ (npm|yarn)[[:space:]]+(run[[:space:]]+(build|test)|test) ]]; then
            notification_title="Build/Test Complete"
            notification_message="Finished: $COMMAND"
            should_notify=true
        elif [[ "$COMMAND" =~ anchor[[:space:]]+(build|test|deploy) ]]; then
            notification_title="Anchor Operation"
            notification_message="Completed: $COMMAND"
            should_notify=true
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
    send_notification "$notification_title" "$notification_message"
    
    # Log to file for debugging (optional)
    if [ -n "$CLAUDE_HOOK_LOG" ]; then
        echo "[$(date)] $notification_title: $notification_message" >> "$CLAUDE_HOOK_LOG"
    fi
fi

# Always pass through the input
echo "$INPUT"

# Log hook completion
log_performance "$HOOK_NAME" $START_TIME
log_hook_end "$HOOK_NAME" 0

exit 0

