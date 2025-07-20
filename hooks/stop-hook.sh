#!/bin/bash

# Direct Stop Hook Handler - No Node.js dependencies
# Processes Stop events and runs code quality checks

set -euo pipefail

# Read input from stdin
INPUT=$(cat)

# Extract event type
EVENT_TYPE=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4)

# Only process Stop events
if [[ "$EVENT_TYPE" != "Stop" ]]; then
    exit 0
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the quality validator
source "$SCRIPT_DIR/code-quality-validator.sh"

# The validator will handle the rest