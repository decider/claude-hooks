#!/bin/bash

# Claude Code Hook: Prevent installation of outdated packages
# This hook intercepts npm/yarn install commands and validates package age

# Source logging library
HOOK_NAME="check-package-age"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

# Start performance timing
START_TIME=$(date +%s)

# Check if we're in test mode
TEST_MODE=${CLAUDE_HOOKS_TEST_MODE:-0}

# Configuration
MAX_AGE_DAYS=${MAX_AGE_DAYS:-180}  # Default: 6 months
CURRENT_DATE=$(date +%s)

# Parse the hook input from stdin
INPUT=$(cat)
log_hook_start "$HOOK_NAME" "$INPUT"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // "No description"')

log_debug "$HOOK_NAME" "Tool: $TOOL_NAME, Command: $COMMAND"

# Only process Bash tool calls
if [ "$TOOL_NAME" != "Bash" ]; then
    log_decision "$HOOK_NAME" "skip" "Not a Bash tool call"
    log_hook_end "$HOOK_NAME" 0
    exit 0
fi

# Function to check package age from npm registry
check_package_age() {
    local package_spec="$1"
    local package_name=""
    local version=""
    
    # Parse package@version or just package name
    if [[ "$package_spec" =~ ^([^@]+)@(.+)$ ]]; then
        package_name="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"
    else
        package_name="$package_spec"
        version="latest"
    fi
    
    # Skip if it's a local file path or git URL
    if [[ "$package_spec" =~ ^(\.|\/|git\+|http|file:) ]]; then
        log_debug "$HOOK_NAME" "Skipping non-npm package: $package_spec"
        return 0
    fi
    
    # In test mode, simulate old package detection for known test packages
    if [ "$TEST_MODE" = "1" ]; then
        case "$package_spec" in
            "left-pad@1.0.0"|"moment@2.18.0")
                echo "Package ${package_name}@${version} is too old (test mode simulation)." >&2
                return 1
                ;;
            *)
                return 0
                ;;
        esac
    fi
    
    # Query npm registry for package info
    local registry_url="https://registry.npmjs.org/${package_name}"
    local package_info=$(curl -s --max-time 5 "$registry_url" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$package_info" ]; then
        # If we can't fetch package info, allow installation (fail open)
        log_warn "$HOOK_NAME" "Could not fetch package info for $package_name, allowing installation"
        return 0
    fi
    
    # Get the publish time for the specific version
    local publish_time=""
    if [ "$version" = "latest" ]; then
        local latest_version=$(echo "$package_info" | jq -r '."dist-tags".latest // empty')
        if [ -n "$latest_version" ]; then
            publish_time=$(echo "$package_info" | jq -r ".time[\"$latest_version\"] // empty")
        fi
    else
        publish_time=$(echo "$package_info" | jq -r ".time[\"$version\"] // empty")
    fi
    
    if [ -z "$publish_time" ]; then
        # Can't determine publish time, allow installation
        return 0
    fi
    
    # Convert publish time to seconds since epoch
    local publish_date=$(date -d "$publish_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${publish_time%%.*}" +%s 2>/dev/null)
    
    if [ -z "$publish_date" ]; then
        return 0
    fi
    
    # Calculate age in days
    local age_days=$(( ($CURRENT_DATE - $publish_date) / 86400 ))
    
    if [ $age_days -gt $MAX_AGE_DAYS ]; then
        # Get latest version info
        local latest_version=$(echo "$package_info" | jq -r '."dist-tags".latest // empty')
        local latest_time=$(echo "$package_info" | jq -r ".time[\"$latest_version\"] // empty")
        local latest_date=$(date -d "$latest_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${latest_time%%.*}" +%s 2>/dev/null)
        local latest_age_days=$(( ($CURRENT_DATE - $latest_date) / 86400 ))
        
        # Build error message
        local error_msg="Package ${package_name}@${version} is too old (published ${age_days} days ago, max allowed: ${MAX_AGE_DAYS} days)."
        
        if [ -n "$latest_version" ] && [ "$latest_version" != "$version" ]; then
            error_msg="$error_msg Latest version is ${latest_version} (${latest_age_days} days old)."
        fi
        
        log_warn "$HOOK_NAME" "$error_msg"
        echo "$error_msg" >&2
        return 1
    fi
    
    log_info "$HOOK_NAME" "Package ${package_name}@${version} is ${age_days} days old (within ${MAX_AGE_DAYS} day limit)"
    
    return 0
}

# Check if this is an npm/yarn install command
if [[ "$COMMAND" =~ ^npm[[:space:]]+install|^npm[[:space:]]+i[[:space:]]|^yarn[[:space:]]+add[[:space:]] ]]; then
    # Extract packages from the command
    packages=()
    
    # Remove command prefix and flags
    cmd_without_prefix=$(echo "$COMMAND" | sed -E 's/^(npm (install|i)|yarn add)[[:space:]]*//')
    
    # Parse packages (handle multiple packages and flags)
    while read -r token; do
        # Skip flags (start with -)
        if [[ ! "$token" =~ ^- ]] && [ -n "$token" ]; then
            packages+=("$token")
        fi
    done < <(echo "$cmd_without_prefix" | tr ' ' '\n')
    
    # Check each package
    failed=false
    log_info "$HOOK_NAME" "Checking ${#packages[@]} package(s) for age compliance"
    for pkg in "${packages[@]}"; do
        if ! check_package_age "$pkg"; then
            failed=true
        fi
    done
    
    if [ "$failed" = true ]; then
        # Output error message to stderr for blocking
        local block_reason="One or more packages are too old. Please use newer versions or add them to the allowlist if absolutely necessary."
        echo "$block_reason" >&2
        log_decision "$HOOK_NAME" "block" "$block_reason"
        
        # Output JSON response to stdout for advanced control
        cat <<EOF
{
  "decision": "block",
  "reason": "One or more packages are too old. Please use newer versions or add them to the allowlist if absolutely necessary.",
  "continue": false
}
EOF
        # In test mode, don't actually block - just return success to allow tests to continue
        if [ "$TEST_MODE" = "1" ]; then
            echo "[TEST MODE] Would have blocked with exit code 2" >&2
            log_info "$HOOK_NAME" "Test mode - would have blocked"
            log_performance "$HOOK_NAME" $START_TIME
            log_hook_end "$HOOK_NAME" 0
            exit 0
        else
            log_performance "$HOOK_NAME" $START_TIME
            log_hook_end "$HOOK_NAME" 2
            exit 2  # Exit code 2 blocks the action
        fi
    else
        log_decision "$HOOK_NAME" "allow" "All packages are within age limit"
    fi
fi

# Check if this is editing package.json to add dependencies
if [[ "$COMMAND" =~ package\.json ]] || [[ "$DESCRIPTION" =~ package\.json ]]; then
    # For now, we'll allow package.json edits but log them
    echo "Notice: package.json edit detected. Ensure dependencies are up to date." >&2
    log_info "$HOOK_NAME" "package.json edit detected - reminder to check dependency versions"
fi

# Allow the command to proceed
log_performance "$HOOK_NAME" $START_TIME
log_hook_end "$HOOK_NAME" 0
exit 0