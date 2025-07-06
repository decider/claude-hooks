#!/bin/bash

# Claude Hooks Log Cleaner
# Cleans old log files and manages log rotation

LOGS_DIR="${CLAUDE_LOGS_DIR:-$HOME/.local/share/claude-hooks/logs}"
LOG_FILE="${CLAUDE_LOG_FILE:-$LOGS_DIR/hooks.log}"
RETENTION_DAYS="${CLAUDE_LOG_RETENTION_DAYS:-7}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧹 Claude Hooks Log Cleaner${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if logs directory exists
if [ ! -d "$LOGS_DIR" ]; then
    echo -e "${YELLOW}⚠️  No logs directory found at: $LOGS_DIR${NC}"
    exit 0
fi

# Find current log size
if [ -f "$LOG_FILE" ]; then
    current_size=$(du -h "$LOG_FILE" | cut -f1)
    echo -e "Current log file: ${GREEN}$LOG_FILE${NC}"
    echo -e "Current size: ${GREEN}$current_size${NC}"
fi

# Find old log files
echo -e "\n🔍 Searching for old log files (older than $RETENTION_DAYS days)..."
old_files=$(find "$LOGS_DIR" -name "hooks.log.*" -type f -mtime +$RETENTION_DAYS 2>/dev/null)

if [ -z "$old_files" ]; then
    echo -e "${GREEN}✅ No old log files found${NC}"
else
    echo -e "${YELLOW}Found old log files:${NC}"
    echo "$old_files" | while read file; do
        size=$(du -h "$file" | cut -f1)
        age=$(( ($(date +%s) - $(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null)) / 86400 ))
        echo -e "  📄 $file (${size}, ${age} days old)"
    done
    
    # Calculate total size
    total_size=$(echo "$old_files" | xargs du -ch 2>/dev/null | tail -1 | cut -f1)
    echo -e "\nTotal size of old files: ${YELLOW}$total_size${NC}"
    
    # Ask for confirmation
    echo ""
    read -p "Delete these old log files? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$old_files" | while read file; do
            rm -f "$file"
            echo -e "${GREEN}✅ Deleted: $file${NC}"
        done
        echo -e "\n${GREEN}✅ Old log files cleaned up${NC}"
    else
        echo -e "${YELLOW}⚠️  Cleanup cancelled${NC}"
    fi
fi

# Option to rotate current log
if [ -f "$LOG_FILE" ]; then
    echo ""
    read -p "Rotate current log file? (y/N): " rotate
    
    if [[ "$rotate" =~ ^[Yy]$ ]]; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        rotated_file="${LOG_FILE}.${timestamp}"
        mv "$LOG_FILE" "$rotated_file"
        echo -e "${GREEN}✅ Rotated to: $rotated_file${NC}"
        
        # Create new empty log file
        touch "$LOG_FILE"
        echo -e "${GREEN}✅ Created new log file${NC}"
    fi
fi

# Show disk usage
echo -e "\n📊 Log directory disk usage:"
du -sh "$LOGS_DIR" 2>/dev/null || echo "Unable to calculate"

echo -e "\n${GREEN}✅ Log maintenance complete${NC}"