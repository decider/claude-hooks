#!/bin/bash
# Universal hook wrapper for Claude Code

# Always log that we're starting
echo "[WRAPPER] Universal hook wrapper called at $(date)" >> /Users/danseider/claude-hooks/.claude/hooks/wrapper.log

# Change to the project directory
cd /Users/danseider/claude-hooks

# Run the universal hook
node lib/commands/universal-hook.js