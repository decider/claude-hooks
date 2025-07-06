#!/bin/bash

# Claude Hooks Log Viewer
# Interactive tool to view and analyze hook logs

LOG_FILE="${CLAUDE_LOG_FILE:-$HOME/.claude/logs/hooks.log}"
LINES_TO_SHOW=50

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 Claude Hooks Log Viewer${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}⚠️  No log file found at: $LOG_FILE${NC}"
    echo -e "${YELLOW}   Hooks may not have run yet or logging may be disabled${NC}"
    exit 0
fi

# Function to colorize log levels
colorize_logs() {
    sed -E "s/\[ERROR\]/$(printf '\033[0;31m')[ERROR]$(printf '\033[0m')/g" | \
    sed -E "s/\[WARN\]/$(printf '\033[1;33m')[WARN]$(printf '\033[0m')/g" | \
    sed -E "s/\[INFO\]/$(printf '\033[0;32m')[INFO]$(printf '\033[0m')/g" | \
    sed -E "s/\[DEBUG\]/$(printf '\033[0;36m')[DEBUG]$(printf '\033[0m')/g"
}

# Main menu
while true; do
    echo ""
    echo "📋 Options:"
    echo "  1) View recent logs (last $LINES_TO_SHOW lines)"
    echo "  2) View all logs"
    echo "  3) Filter by hook name"
    echo "  4) Filter by log level"
    echo "  5) Show statistics"
    echo "  6) Follow logs in real-time"
    echo "  7) Search logs"
    echo "  q) Quit"
    echo ""
    read -p "Select an option: " choice

    case $choice in
        1)
            echo -e "\n${CYAN}📜 Recent Logs:${NC}"
            tail -n $LINES_TO_SHOW "$LOG_FILE" | colorize_logs
            ;;
        2)
            echo -e "\n${CYAN}📜 All Logs:${NC}"
            cat "$LOG_FILE" | colorize_logs | less -R
            ;;
        3)
            read -p "Enter hook name to filter: " hook_name
            echo -e "\n${CYAN}📜 Logs for hook: $hook_name${NC}"
            grep "\[$hook_name\]" "$LOG_FILE" | colorize_logs | less -R
            ;;
        4)
            echo "Select log level:"
            echo "  1) ERROR"
            echo "  2) WARN"
            echo "  3) INFO"
            echo "  4) DEBUG"
            read -p "Choice: " level_choice
            
            case $level_choice in
                1) level="ERROR" ;;
                2) level="WARN" ;;
                3) level="INFO" ;;
                4) level="DEBUG" ;;
                *) continue ;;
            esac
            
            echo -e "\n${CYAN}📜 $level logs:${NC}"
            grep "\[$level\]" "$LOG_FILE" | colorize_logs | less -R
            ;;
        5)
            echo -e "\n${CYAN}📊 Hook Statistics:${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            
            # Total logs
            total_logs=$(wc -l < "$LOG_FILE")
            echo -e "Total log entries: ${GREEN}$total_logs${NC}"
            
            # Logs by level
            echo -e "\nLogs by level:"
            for level in ERROR WARN INFO DEBUG; do
                count=$(grep -c "\[$level\]" "$LOG_FILE" 2>/dev/null || echo 0)
                case $level in
                    ERROR) color=$RED ;;
                    WARN) color=$YELLOW ;;
                    INFO) color=$GREEN ;;
                    DEBUG) color=$CYAN ;;
                esac
                printf "  ${color}%-7s${NC}: %d\n" "$level" "$count"
            done
            
            # Most active hooks
            echo -e "\nMost active hooks:"
            awk -F'[][]' '/\[.*\] \[.*\] \[.*\]/ {print $6}' "$LOG_FILE" | \
                sort | uniq -c | sort -rn | head -10 | \
                while read count hook; do
                    printf "  %-30s: %d\n" "$hook" "$count"
                done
            
            # Recent errors
            error_count=$(grep -c "\[ERROR\]" "$LOG_FILE" 2>/dev/null || echo 0)
            if [ $error_count -gt 0 ]; then
                echo -e "\n${RED}Recent errors:${NC}"
                grep "\[ERROR\]" "$LOG_FILE" | tail -5 | colorize_logs
            fi
            ;;
        6)
            echo -e "\n${CYAN}📡 Following logs (Ctrl+C to stop):${NC}"
            tail -f "$LOG_FILE" | colorize_logs
            ;;
        7)
            read -p "Enter search term: " search_term
            echo -e "\n${CYAN}🔍 Search results for: $search_term${NC}"
            grep -i "$search_term" "$LOG_FILE" | colorize_logs | less -R
            ;;
        q|Q)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
done