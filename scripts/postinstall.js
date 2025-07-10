#!/usr/bin/env node

// Only show message when installed globally
if (process.env.npm_config_global === 'true') {
  console.log();
  console.log('✅ Claude Hooks CLI installed successfully!');
  console.log();
  console.log('🚀 Get started:');
  console.log('   claude-hooks        Open the interactive hook manager');
  console.log('   claude-hooks init   Set up hooks for your project');
  console.log('   claude-hooks list   See all available hooks');
  console.log();
  console.log('📚 Documentation: https://github.com/anthropics/claude-code-hooks-cli');
  console.log();
}