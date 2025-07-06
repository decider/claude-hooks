#!/bin/bash

# Script to add logging to all hooks
# This updates existing hooks to use the centralized logging library

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../hooks" && pwd)"
BACKUP_DIR="$HOOKS_DIR/backup-$(date +%Y%m%d_%H%M%S)"

echo "🔧 Adding logging to all hooks..."
echo "📁 Hooks directory: $HOOKS_DIR"
echo "💾 Creating backup at: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# List of hooks to update
HOOKS=(
    "check-package-age.sh"
    "code-quality-validator.sh"
    "code-quality-primer.sh"
    "code-similarity-check.sh"
    "task-completion-notify.sh"
    "pre-commit-check.sh"
    "pre-completion-check.sh"
    "pre-completion-quality-check.sh"
    "post-write.sh"
    "claude-context-updater.sh"
)

# Function to add logging to a hook
add_logging_to_hook() {
    local hook_file="$1"
    local hook_name="${hook_file%.sh}"
    
    echo "📝 Processing: $hook_file"
    
    # Backup original
    cp "$HOOKS_DIR/$hook_file" "$BACKUP_DIR/$hook_file"
    
    # Create temporary file with logging additions
    local temp_file=$(mktemp)
    
    # Read the original file
    local content=$(cat "$HOOKS_DIR/$hook_file")
    
    # Check if logging is already added
    if grep -q "source.*common/logging.sh" "$HOOKS_DIR/$hook_file"; then
        echo "  ✅ Already has logging"
        return 0
    fi
    
    # Add logging header after shebang and initial comments
    awk -v hook_name="$hook_name" '
    BEGIN { 
        printed_logging = 0
        in_header = 1
    }
    {
        # Print the line
        print
        
        # After shebang and comment block, add logging
        if (in_header && NR > 1 && !/^#/ && !printed_logging) {
            print ""
            print "# Source logging library"
            print "HOOK_NAME=\"" hook_name "\""
            print "SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\""
            print "source \"$SCRIPT_DIR/common/logging.sh\""
            print ""
            print "# Start performance timing"
            print "START_TIME=$(date +%s)"
            print ""
            print "# Log hook start"
            print "log_hook_start \"$HOOK_NAME\" \"Hook invoked\""
            print ""
            printed_logging = 1
            in_header = 0
        }
        
        # Detect when we leave the header
        if (!/^#/ && !/^$/) {
            in_header = 0
        }
    }
    END {
        # Add hook end logging before final exit
        print ""
        print "# Log hook completion"
        print "log_performance \"$HOOK_NAME\" $START_TIME"
        print "log_hook_end \"$HOOK_NAME\" 0"
    }
    ' "$HOOKS_DIR/$hook_file" > "$temp_file"
    
    # Replace original with updated version
    mv "$temp_file" "$HOOKS_DIR/$hook_file"
    chmod +x "$HOOKS_DIR/$hook_file"
    
    echo "  ✅ Logging added"
}

# Process each hook
for hook in "${HOOKS[@]}"; do
    if [ -f "$HOOKS_DIR/$hook" ]; then
        add_logging_to_hook "$hook"
    else
        echo "⚠️  Hook not found: $hook"
    fi
done

echo ""
echo "✅ Logging has been added to all hooks!"
echo "💾 Original files backed up to: $BACKUP_DIR"
echo ""
echo "📋 Next steps:"
echo "1. Review the updated hooks to ensure they work correctly"
echo "2. Update the settings.json to configure logging preferences"
echo "3. Test the hooks to verify logging is working"
echo ""
echo "📍 Logs will be written to: ~/.claude/logs/hooks.log"