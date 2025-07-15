#!/usr/bin/env node
import { Command } from 'commander';
import chalk from 'chalk';
import * as fs from 'fs';
import * as path from 'path';
import { HookTestFramework, TestCase } from '../testing/hook-test-framework.js';
import { logger } from '../testing/logger.js';
import { HookTemplate } from '../types.js';
import { discoverHookTemplates } from '../discovery/hook-discovery.js';

export function makeTestCommand() {
  const test = new Command('test')
    .description('Test hooks and validate their behavior')
    .option('-h, --hook <name>', 'Test specific hook by name')
    .option('-e, --event <event>', 'Test hooks for specific event')
    .option('-v, --verbose', 'Show detailed output')
    .option('-w, --watch', 'Watch for changes and re-run tests')
    .option('-c, --continuous', 'Run in continuous mode for development')
    .action(async (options) => {
      try {
        if (options.verbose) {
          logger.setVerbose(true);
        }

        console.log(chalk.bold('🧪 Claude Hooks Test Runner\n'));

        const framework = new HookTestFramework();
        await framework.setup();

        // Discover available hooks
        const templates = await discoverHookTemplates();
        
        // Load test cases
        const testCases = await loadTestCases(options.hook, options.event);
        
        if (testCases.length === 0) {
          console.log(chalk.yellow('No test cases found.'));
          console.log(chalk.gray('Create test cases in .claude/tests/ directory'));
          await framework.teardown();
          return;
        }

        // Build hook commands map
        const hookCommands = new Map<string, string>();
        for (const [name, template] of Object.entries(templates)) {
          if (template.command) {
            hookCommands.set(name, template.command);
          }
        }

        if (options.watch || options.continuous) {
          await runContinuousMode(framework, testCases, hookCommands, options);
        } else {
          await framework.runTests(testCases, hookCommands);
          await framework.teardown();
          
          const results = framework.getResults();
          const failedCount = results.filter(r => !r.passed).length;
          process.exit(failedCount > 0 ? 1 : 0);
        }
      } catch (error: any) {
        console.error(chalk.red('Error:'), error.message);
        process.exit(1);
      }
    });

  return test;
}

async function loadTestCases(hookFilter?: string, eventFilter?: string): Promise<TestCase[]> {
  const testCases: TestCase[] = [];
  const testDir = path.join(process.cwd(), '.claude', 'tests');
  
  // Load built-in test cases
  const builtInTests = await loadBuiltInTests();
  testCases.push(...builtInTests);
  
  // Load project test cases
  if (fs.existsSync(testDir)) {
    const files = fs.readdirSync(testDir);
    for (const file of files) {
      if (file.endsWith('.test.ts') || file.endsWith('.test.js')) {
        try {
          const testPath = path.join(testDir, file);
          const tests = await import(testPath);
          if (tests.default && Array.isArray(tests.default)) {
            testCases.push(...tests.default);
          }
        } catch (error: any) {
          console.warn(chalk.yellow(`Failed to load test: ${file}`), error.message);
        }
      }
    }
  }
  
  // Apply filters
  let filtered = testCases;
  if (hookFilter) {
    filtered = filtered.filter(tc => tc.hook === hookFilter);
  }
  if (eventFilter) {
    filtered = filtered.filter(tc => tc.event.event === eventFilter);
  }
  
  return filtered;
}

async function loadBuiltInTests(): Promise<TestCase[]> {
  // Built-in test cases for common scenarios
  return [
    {
      name: 'PreWrite event triggers before file write',
      hook: 'test-prewrite',
      event: {
        event: 'PreWrite',
        filePath: '/tmp/test-file.txt'
      },
      expect: {
        shouldRun: true,
        exitCode: 0
      }
    },
    {
      name: 'PostWrite event triggers after file write',
      hook: 'test-postwrite',
      event: {
        event: 'PostWrite',
        filePath: '/tmp/test-file.txt'
      },
      expect: {
        shouldRun: true,
        exitCode: 0
      }
    },
    {
      name: 'Hook pattern matching works correctly',
      hook: 'test-pattern',
      event: {
        event: 'PreToolUse',
        matcher: 'Bash',
        pattern: '^git\\s+commit'
      },
      expect: {
        shouldRun: true,
        exitCode: 0
      }
    }
  ];
}

async function runContinuousMode(
  framework: HookTestFramework,
  testCases: TestCase[],
  hookCommands: Map<string, string>,
  options: any
): Promise<void> {
  console.log(chalk.bold('📡 Running in continuous mode\n'));
  console.log(chalk.gray('Press Ctrl+C to exit\n'));
  
  const runTests = async () => {
    console.clear();
    console.log(chalk.bold(`🧪 Test Run - ${new Date().toLocaleTimeString()}\n`));
    await framework.runTests(testCases, hookCommands);
    console.log('\n' + chalk.gray('Waiting for changes...'));
  };
  
  // Initial run
  await runTests();
  
  if (options.watch) {
    // Set up file watcher
    const watchDirs = [
      path.join(process.cwd(), '.claude', 'hooks'),
      path.join(process.cwd(), '.claude', 'tests'),
      path.join(process.cwd(), 'claude', 'hooks'),
      path.join(process.cwd(), 'src')
    ];
    
    const { watch } = await import('fs');
    
    for (const dir of watchDirs) {
      if (fs.existsSync(dir)) {
        watch(dir, { recursive: true }, async (eventType, filename) => {
          if (filename && (filename.endsWith('.ts') || filename.endsWith('.js'))) {
            console.log(chalk.gray(`\nChange detected in ${filename}`));
            await runTests();
          }
        });
      }
    }
  }
  
  // Keep process running
  process.stdin.resume();
  process.on('SIGINT', async () => {
    console.log('\n' + chalk.yellow('Shutting down...'));
    await framework.teardown();
    process.exit(0);
  });
}