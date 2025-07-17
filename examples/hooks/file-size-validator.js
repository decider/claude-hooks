#!/usr/bin/env node
/**
 * Example Hook: File Size Validator
 * 
 * This hook prevents writing files that are too large.
 * It demonstrates how to:
 * - Handle PreWrite events
 * - Access file path and content
 * - Block actions by exiting with non-zero code
 * - Provide helpful error messages
 */

// Configuration
const MAX_FILE_SIZE = 100000; // 100KB
const WARN_FILE_SIZE = 50000; // 50KB

// Read input from stdin
let inputData = '';
process.stdin.on('data', chunk => inputData += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(inputData);
    
    // Only process PreWrite events
    if (input.hook_event_name !== 'PreWrite') {
      process.exit(0);
    }
    
    const filePath = input.file_path;
    const content = input.content;
    const fileSize = Buffer.byteLength(content, 'utf8');
    
    console.log(`📁 Checking file size for: ${filePath}`);
    console.log(`   Size: ${(fileSize / 1024).toFixed(2)} KB`);
    
    // Block files that are too large
    if (fileSize > MAX_FILE_SIZE) {
      console.error(`❌ File too large: ${(fileSize / 1024).toFixed(2)} KB`);
      console.error(`   Maximum allowed: ${(MAX_FILE_SIZE / 1024).toFixed(2)} KB`);
      console.error(`   Consider splitting this file into smaller modules.`);
      process.exit(1); // Non-zero exit blocks the write
    }
    
    // Warn about large files
    if (fileSize > WARN_FILE_SIZE) {
      console.warn(`⚠️  Warning: Large file (${(fileSize / 1024).toFixed(2)} KB)`);
      console.warn(`   Consider refactoring if this file continues to grow.`);
    }
    
    // Check for specific file types that should be small
    if (filePath.endsWith('package.json') && fileSize > 5000) {
      console.warn('⚠️  Warning: package.json is unusually large');
      console.warn('   Consider moving scripts to separate files');
    }
    
    console.log('✅ File size check passed');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error in file-size-validator:', error.message);
    // Exit successfully on error (don't block Claude)
    process.exit(0);
  }
});