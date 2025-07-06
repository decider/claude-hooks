#!/bin/bash

# Claude Hooks Common Logging Library
# Provides centralized logging functionality for all hooks

# Default configuration - logging is ON by default with smart defaults
# Users can disable by setting CLAUDE_LOG_ENABLED=false or in settings.json
CLAUDE_LOGS_DIR="${CLAUDE_LOGS_DIR:-$HOME/.claude/logs}"
CLAUDE_LOG_FILE="${CLAUDE_LOG_FILE:-$CLAUDE_LOGS_DIR/hooks.log}"
CLAUDE_LOG_LEVEL="${CLAUDE_LOG_LEVEL:-INFO}"
CLAUDE_LOG_ENABLED="${CLAUDE_LOG_ENABLED:-true}"  # ON by default
CLAUDE_LOG_MAX_SIZE="${CLAUDE_LOG_MAX_SIZE:-10485760}"  # 10MB default
CLAUDE_LOG_RETENTION_DAYS="${CLAUDE_LOG_RETENTION_DAYS:-7}"

# Log levels
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
)

# Get numeric value for current log level
CURRENT_LOG_LEVEL="${LOG_LEVELS[$CLAUDE_LOG_LEVEL]:-1}"

# Ensure log directory exists
mkdir -p "$CLAUDE_LOGS_DIR"

# Function to rotate logs if needed
rotate_logs() {
    if [ -f "$CLAUDE_LOG_FILE" ]; then
        local size=$(stat -f%z "$CLAUDE_LOG_FILE" 2>/dev/null || stat -c%s "$CLAUDE_LOG_FILE" 2>/dev/null || echo 0)
        if [ "$size" -gt "$CLAUDE_LOG_MAX_SIZE" ]; then
            local timestamp=$(date +%Y%m%d_%H%M%S)
            mv "$CLAUDE_LOG_FILE" "${CLAUDE_LOG_FILE}.${timestamp}"
            
            # Clean up old logs
            find "$CLAUDE_LOGS_DIR" -name "hooks.log.*" -mtime +$CLAUDE_LOG_RETENTION_DAYS -delete 2>/dev/null
        fi
    fi
}

# Main logging function
log() {
    local level=$1
    local hook_name=$2
    shift 2
    local message="$*"
    
    # Check if logging is enabled
    if [ "$CLAUDE_LOG_ENABLED" != "true" ]; then
        return 0
    fi
    
    # Check log level
    local level_value="${LOG_LEVELS[$level]:-1}"
    if [ "$level_value" -lt "$CURRENT_LOG_LEVEL" ]; then
        return 0
    fi
    
    # Rotate logs if needed
    rotate_logs
    
    # Format timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write log entry
    echo "[$timestamp] [$level] [$hook_name] $message" >> "$CLAUDE_LOG_FILE"
}

# Convenience logging functions
log_debug() {
    local hook_name=$1
    shift
    log "DEBUG" "$hook_name" "$@"
}

log_info() {
    local hook_name=$1
    shift
    log "INFO" "$hook_name" "$@"
}

log_warn() {
    local hook_name=$1
    shift
    log "WARN" "$hook_name" "$@"
}

log_error() {
    local hook_name=$1
    shift
    log "ERROR" "$hook_name" "$@"
}

# Function to log hook entry
log_hook_start() {
    local hook_name=$1
    local input=$2
    
    log_info "$hook_name" "Hook started"
    if [ -n "$input" ] && [ "$CURRENT_LOG_LEVEL" -le "${LOG_LEVELS[DEBUG]}" ]; then
        # Sanitize input for logging (remove sensitive data)
        local sanitized_input=$(echo "$input" | jq -r 'del(.secrets, .passwords, .tokens)' 2>/dev/null || echo "$input")
        log_debug "$hook_name" "Input: $sanitized_input"
    fi
}

# Function to log hook exit
log_hook_end() {
    local hook_name=$1
    local exit_code=$2
    
    if [ "$exit_code" -eq 0 ]; then
        log_info "$hook_name" "Hook completed successfully (exit code: $exit_code)"
    else
        log_error "$hook_name" "Hook failed (exit code: $exit_code)"
    fi
}

# Function to log hook decision
log_decision() {
    local hook_name=$1
    local decision=$2
    local reason=$3
    
    log_info "$hook_name" "Decision: $decision - $reason"
}

# Function to log performance metrics
log_performance() {
    local hook_name=$1
    local start_time=$2
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_debug "$hook_name" "Execution time: ${duration}s"
}

# Load configuration from settings.json if available
# This ONLY runs if settings.json exists - otherwise we use defaults
load_logging_config() {
    local settings_file="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"
    
    # Only load config if file exists - no error if missing
    if [ -f "$settings_file" ]; then
        # Check if logging section exists
        local has_logging=$(jq -r 'has("logging")' "$settings_file" 2>/dev/null)
        
        if [ "$has_logging" = "true" ]; then
            # Extract logging configuration
            local enabled=$(jq -r '.logging.enabled // empty' "$settings_file" 2>/dev/null)
            local level=$(jq -r '.logging.level // empty' "$settings_file" 2>/dev/null)
            local path=$(jq -r '.logging.path // empty' "$settings_file" 2>/dev/null)
            local max_size=$(jq -r '.logging.maxSize // empty' "$settings_file" 2>/dev/null)
            local retention=$(jq -r '.logging.retention // empty' "$settings_file" 2>/dev/null)
            
            # Apply configuration only if explicitly set
            [ -n "$enabled" ] && [ "$enabled" != "null" ] && CLAUDE_LOG_ENABLED="$enabled"
            [ -n "$level" ] && [ "$level" != "null" ] && CLAUDE_LOG_LEVEL="$level"
            [ -n "$path" ] && [ "$path" != "null" ] && CLAUDE_LOG_FILE="$path"
            [ -n "$max_size" ] && [ "$max_size" != "null" ] && CLAUDE_LOG_MAX_SIZE="$max_size"
            [ -n "$retention" ] && [ "$retention" != "null" ] && CLAUDE_LOG_RETENTION_DAYS="$retention"
            
            # Update current log level
            CURRENT_LOG_LEVEL="${LOG_LEVELS[$CLAUDE_LOG_LEVEL]:-1}"
        fi
    fi
    # If no settings.json or no logging section, we just use the defaults
}

# Initialize logging configuration
load_logging_config