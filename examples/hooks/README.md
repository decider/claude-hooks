# Example Hooks

This directory contains example hooks demonstrating how to write custom hooks for Claude Code.

## Examples Included

### 1. bash-command-logger.js
- **Event**: PreToolUse (Bash only)
- **Purpose**: Logs all Bash commands to a history file
- **Demonstrates**: Reading stdin, filtering events, file logging

### 2. file-size-validator.js
- **Event**: PreWrite
- **Purpose**: Prevents writing files that are too large
- **Demonstrates**: Blocking actions, validation, error messages

### 3. multi-event-monitor.js
- **Event**: All events
- **Purpose**: Monitors and logs all Claude activity
- **Demonstrates**: Handling multiple events, session tracking, stats

## Running the Examples

1. Make the hook executable:
   ```bash
   chmod +x bash-command-logger.js
   ```

2. Test with sample input:
   ```bash
   echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"}}' | ./bash-command-logger.js
   ```

3. Add to your config:
   ```javascript
   // .claude/hooks/config.cjs
   module.exports = {
     preToolUse: ['bash-command-logger'],
     preWrite: ['file-size-validator'],
     // ... other hooks
   };
   ```

## Key Concepts Demonstrated

- **Reading stdin**: All hooks receive JSON data via stdin
- **Event filtering**: Check `hook_event_name` to handle specific events
- **Tool filtering**: Check `tool_name` for tool-specific logic
- **Exit codes**: Use 0 for success, non-zero to block actions
- **Error handling**: Always wrap in try-catch, fail gracefully
- **Logging**: Use console.log for user messages, console.error for errors

## Creating Your Own Hooks

Use these examples as templates for your own hooks. Key steps:

1. Read JSON from stdin
2. Check the event type
3. Extract relevant data
4. Perform your logic
5. Exit with appropriate code

See the [Hook Development Guide](../../docs/HOOK-DEVELOPMENT.md) for detailed documentation.