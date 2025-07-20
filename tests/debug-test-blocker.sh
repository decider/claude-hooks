#!/bin/bash
# Debug why test-blocker doesn't exit with code 2

echo "=== Debugging test-blocker hook ==="
echo

# Test input
INPUT='{
  "session_id": "test",
  "transcript_path": "/tmp/test.jsonl",
  "hook_event_name": "PreWrite",
  "file_path": "test.block-test.txt"
}'

echo "1. Direct hook test (should output JSON with exit 0)"
echo "---------------------------------------------------"
echo "$INPUT" | ./hooks/test-blocker.sh
echo "Exit code: $?"
echo

echo "2. Universal hook test (should exit with code 2)"
echo "------------------------------------------------"
# Run with debug to see what's happening
echo "$INPUT" | HOOK_DEBUG=1 node lib/commands/universal-hook.js 2>&1
echo "Exit code: $?"
echo

echo "3. Test the specific path through universal-hook"
echo "-----------------------------------------------"
# Create a test that shows the exact flow
cat > /tmp/test-flow.js << 'EOF'
import { spawn } from 'child_process';

const input = {
  session_id: "test",
  transcript_path: "/tmp/test.jsonl", 
  hook_event_name: "PreWrite",
  file_path: "test.block-test.txt"
};

console.log("Checking config for PreWrite hooks...");

// Check what hooks would run
const configKey = 'preWrite';
console.log(`Config key: ${configKey}`);

// Would load config and check patterns
console.log("Would match pattern: \\.block-test\\.(txt|md)$");
console.log("Would execute: test-blocker");

// Test the hook execution
const child = spawn('npx', ['claude-code-hooks-cli', 'exec', 'test-blocker'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

let stdout = '';
child.stdout.on('data', (data) => {
  stdout += data.toString();
});

child.stderr.on('data', (data) => {
  console.error('Stderr:', data.toString());
});

child.stdin.write(JSON.stringify(input));
child.stdin.end();

child.on('close', (code) => {
  console.log('Hook exit code:', code);
  console.log('Stdout length:', stdout.length);
  
  try {
    const output = JSON.parse(stdout.trim());
    console.log('Parsed output:', output);
    
    if (output.continue === false) {
      console.log('SHOULD EXIT WITH CODE 2');
      process.exit(2);
    }
  } catch (e) {
    console.log('Parse error:', e.message);
  }
});
EOF

node /tmp/test-flow.js
echo "Exit code: $?"

# Clean up
rm -f /tmp/test-flow.js