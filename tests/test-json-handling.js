#!/usr/bin/env node
/**
 * Test to verify JSON output handling in universal-hook
 */

import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

console.log('=== Testing JSON Output Handling ===\n');

// Test 1: Test hook that outputs JSON with continue: false
async function testJsonBlocking() {
  console.log('Test 1: Hook outputs JSON with continue: false');
  console.log('----------------------------------------------');
  
  const testInput = {
    session_id: "test-123",
    transcript_path: "/tmp/test.jsonl",
    hook_event_name: "PreWrite",
    file_path: "test.block-test.txt",
    content: "This should be blocked"
  };
  
  return new Promise((resolve) => {
    const child = spawn('node', [path.join(__dirname, '../lib/commands/universal-hook.js')], {
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, HOOK_DEBUG: '1' }
    });
    
    let stdout = '';
    let stderr = '';
    
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });
    
    child.on('close', (code) => {
      console.log('Exit code:', code);
      console.log('Stdout:', stdout);
      console.log('Stderr:', stderr);
      
      if (code === 2) {
        console.log('✅ Correctly exited with code 2');
        if (stderr.includes('Hook stopped execution:')) {
          console.log('✅ Stop message found in stderr');
        } else {
          console.log('❌ Stop message NOT found in stderr');
        }
      } else {
        console.log('❌ Did NOT exit with code 2');
      }
      
      console.log();
      resolve();
    });
    
    // Send input
    child.stdin.write(JSON.stringify(testInput));
    child.stdin.end();
  });
}

// Test 2: Direct test of executeHook function
async function testExecuteHook() {
  console.log('Test 2: Direct test of executeHook function');
  console.log('-------------------------------------------');
  
  // Create a minimal test to see if executeHook captures stdout
  const testScript = `
import { spawn } from 'child_process';

async function executeHook(hookName, input) {
  return new Promise((resolve, reject) => {
    const child = spawn('npx', ['claude-code-hooks-cli', 'exec', hookName], {
      stdio: ['pipe', 'pipe', 'inherit']  // This should capture stdout
    });
    
    let stdout = '';
    
    child.stdout.on('data', (data) => {
      stdout += data.toString();
      console.log('[CAPTURED STDOUT]:', data.toString());
    });
    
    child.stdin.write(JSON.stringify(input));
    child.stdin.end();
    
    child.on('close', (code) => {
      console.log('[STDOUT LENGTH]:', stdout.length);
      console.log('[EXIT CODE]:', code);
      
      if (stdout.trim()) {
        try {
          const output = JSON.parse(stdout.trim());
          console.log('[PARSED JSON]:', output);
          
          if (output.continue === false) {
            console.log('[BLOCKING] continue: false detected');
            process.exit(2);
          }
        } catch (e) {
          console.log('[NOT JSON]:', stdout);
        }
      }
      
      resolve();
    });
  });
}

// Test it
executeHook('test-blocker', {
  session_id: "test",
  transcript_path: "/tmp/test.jsonl", 
  hook_event_name: "PreWrite",
  file_path: "test.txt"
}).catch(console.error);
`;

  const child = spawn('node', ['-e', testScript], {
    stdio: 'inherit'
  });
  
  return new Promise((resolve) => {
    child.on('close', () => {
      console.log();
      resolve();
    });
  });
}

// Test 3: Check if npx command works correctly
async function testNpxCommand() {
  console.log('Test 3: Test npx command directly');
  console.log('---------------------------------');
  
  const testInput = {
    session_id: "test-123",
    hook_event_name: "PreWrite",
    file_path: "test.txt"
  };
  
  return new Promise((resolve) => {
    const child = spawn('npx', ['claude-code-hooks-cli', 'exec', 'test-blocker'], {
      stdio: ['pipe', 'pipe', 'pipe']
    });
    
    let stdout = '';
    let stderr = '';
    
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });
    
    child.on('close', (code) => {
      console.log('Exit code:', code);
      console.log('Stdout length:', stdout.length);
      console.log('First 200 chars of stdout:', stdout.substring(0, 200));
      
      try {
        const parsed = JSON.parse(stdout.trim());
        console.log('✅ Valid JSON output');
        console.log('continue:', parsed.continue);
        console.log('stopReason:', parsed.stopReason);
      } catch (e) {
        console.log('❌ Invalid JSON output');
      }
      
      console.log();
      resolve();
    });
    
    child.stdin.write(JSON.stringify(testInput));
    child.stdin.end();
  });
}

// Run all tests
async function runTests() {
  await testJsonBlocking();
  await testExecuteHook();
  await testNpxCommand();
  
  console.log('=== Summary ===');
  console.log('Check above results to verify:');
  console.log('1. Universal hook exits with code 2 when continue: false');
  console.log('2. executeHook properly captures stdout');
  console.log('3. JSON is parsed correctly');
}

runTests().catch(console.error);