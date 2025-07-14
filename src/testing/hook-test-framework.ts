import { spawn } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import chalk from 'chalk';
import { HookLogger, logger } from './logger.js';
import { HookConfig, HookSettings } from '../types.js';

export interface TestEvent {
  event: string;
  matcher?: string;
  pattern?: string;
  data?: any;
  filePath?: string;
}

export interface TestExpectation {
  shouldRun: boolean;
  exitCode?: number;
  outputContains?: string[];
  outputNotContains?: string[];
  duration?: { min?: number; max?: number };
  customValidator?: (result: TestResult) => boolean;
}

export interface TestCase {
  name: string;
  hook: string;
  event: TestEvent;
  setup?: () => Promise<void>;
  teardown?: () => Promise<void>;
  expect: TestExpectation;
}

export interface TestResult {
  name: string;
  hook: string;
  passed: boolean;
  ran: boolean;
  output: string;
  error: string;
  exitCode: number | null;
  duration: number;
  logs: any[];
  failureReason?: string;
}

export class HookTestFramework {
  private settingsPath: string;
  private testSettingsPath: string;
  private originalSettings?: HookSettings;
  private results: TestResult[] = [];

  constructor(settingsPath?: string) {
    this.settingsPath = settingsPath || path.join(process.env.HOME!, '.claude', 'settings.json');
    this.testSettingsPath = path.join(process.env.HOME!, '.claude', 'test-settings.json');
    logger.setTestMode(true);
    logger.setVerbose(true);
  }

  async setup(): Promise<void> {
    // Backup original settings
    if (fs.existsSync(this.settingsPath)) {
      this.originalSettings = JSON.parse(fs.readFileSync(this.settingsPath, 'utf8'));
      fs.copyFileSync(this.settingsPath, this.testSettingsPath);
    }
  }

  async teardown(): Promise<void> {
    // Restore original settings
    if (this.originalSettings) {
      fs.writeFileSync(this.settingsPath, JSON.stringify(this.originalSettings, null, 2));
    }
    if (fs.existsSync(this.testSettingsPath)) {
      fs.unlinkSync(this.testSettingsPath);
    }
    logger.close();
  }

  private createTestSettings(hookName: string, hookConfig: HookConfig, command: string): HookSettings {
    const settings: HookSettings = {
      _comment: "Test settings for hook validation",
      hooks: {}
    };

    if (!settings.hooks[hookConfig.event]) {
      settings.hooks[hookConfig.event] = [];
    }

    settings.hooks[hookConfig.event].push({
      matcher: hookConfig.matcher,
      pattern: hookConfig.pattern,
      hooks: [{
        type: 'command',
        command: command
      }]
    });

    return settings;
  }

  async runTest(test: TestCase, hookCommand: string): Promise<TestResult> {
    logger.info('test-framework', `Starting test: ${test.name}`);
    const startTime = Date.now();
    
    const result: TestResult = {
      name: test.name,
      hook: test.hook,
      passed: false,
      ran: false,
      output: '',
      error: '',
      exitCode: null,
      duration: 0,
      logs: []
    };

    try {
      // Run setup
      if (test.setup) {
        await test.setup();
      }

      // Simulate the event
      logger.hookStart(test.hook, test.event.event, test.event.data);
      
      const hookResult = await this.executeHook(
        hookCommand,
        test.event,
        test.hook
      );

      result.ran = true;
      result.output = hookResult.output;
      result.error = hookResult.error;
      result.exitCode = hookResult.exitCode;
      result.duration = Date.now() - startTime;
      result.logs = logger.getTestLogs();

      // Validate expectations
      result.passed = this.validateExpectations(result, test.expect);
      
      logger.hookEnd(test.hook, test.event.event, result.duration, result.passed);

      // Run teardown
      if (test.teardown) {
        await test.teardown();
      }
    } catch (error: any) {
      result.error = error.message;
      result.failureReason = `Test execution failed: ${error.message}`;
      logger.error('test-framework', `Test failed: ${error.message}`);
    }

    logger.clearTestLogs();
    this.results.push(result);
    return result;
  }

  private async executeHook(
    command: string,
    event: TestEvent,
    hookName: string
  ): Promise<{ output: string; error: string; exitCode: number }> {
    return new Promise((resolve) => {
      const env: NodeJS.ProcessEnv = {
        ...process.env,
        CLAUDE_HOOK_EVENT: event.event,
        CLAUDE_HOOK_MATCHER: event.matcher || '',
        CLAUDE_HOOK_PATTERN: event.pattern || '',
        CLAUDE_HOOK_NAME: hookName,
        CLAUDE_HOOK_TEST_MODE: 'true'
      };

      if (event.filePath) {
        env['CLAUDE_HOOK_FILE_PATH'] = event.filePath;
      }

      if (event.data) {
        env['CLAUDE_HOOK_EVENT_DATA'] = JSON.stringify(event.data);
      }

      logger.debug(hookName, `Executing command: ${command}`, { env });

      const proc = spawn(command, [], {
        shell: true,
        env,
        cwd: process.cwd()
      });

      let output = '';
      let error = '';

      proc.stdout.on('data', (data) => {
        output += data.toString();
      });

      proc.stderr.on('data', (data) => {
        error += data.toString();
      });

      proc.on('close', (code) => {
        resolve({
          output,
          error,
          exitCode: code || 0
        });
      });
    });
  }

  private validateExpectations(result: TestResult, expect: TestExpectation): boolean {
    const failures: string[] = [];

    // Check if hook should have run
    if (expect.shouldRun && !result.ran) {
      failures.push('Hook did not run when expected');
    } else if (!expect.shouldRun && result.ran) {
      failures.push('Hook ran when not expected');
    }

    if (!expect.shouldRun) {
      return failures.length === 0;
    }

    // Check exit code
    if (expect.exitCode !== undefined && result.exitCode !== expect.exitCode) {
      failures.push(`Expected exit code ${expect.exitCode}, got ${result.exitCode}`);
    }

    // Check output contains
    if (expect.outputContains) {
      for (const str of expect.outputContains) {
        if (!result.output.includes(str)) {
          failures.push(`Output does not contain: "${str}"`);
        }
      }
    }

    // Check output not contains
    if (expect.outputNotContains) {
      for (const str of expect.outputNotContains) {
        if (result.output.includes(str)) {
          failures.push(`Output should not contain: "${str}"`);
        }
      }
    }

    // Check duration
    if (expect.duration) {
      if (expect.duration.min !== undefined && result.duration < expect.duration.min) {
        failures.push(`Duration ${result.duration}ms is less than minimum ${expect.duration.min}ms`);
      }
      if (expect.duration.max !== undefined && result.duration > expect.duration.max) {
        failures.push(`Duration ${result.duration}ms exceeds maximum ${expect.duration.max}ms`);
      }
    }

    // Custom validator
    if (expect.customValidator && !expect.customValidator(result)) {
      failures.push('Custom validation failed');
    }

    if (failures.length > 0) {
      result.failureReason = failures.join('; ');
    }

    return failures.length === 0;
  }

  async runTests(tests: TestCase[], hookCommands: Map<string, string>): Promise<void> {
    console.log(chalk.bold('\n🧪 Running Hook Tests\n'));

    for (const test of tests) {
      const command = hookCommands.get(test.hook);
      if (!command) {
        console.log(chalk.red(`❌ ${test.name}: Hook command not found`));
        continue;
      }

      const result = await this.runTest(test, command);
      this.printTestResult(result);
    }

    this.printSummary();
  }

  private printTestResult(result: TestResult): void {
    const status = result.passed ? chalk.green('✓') : chalk.red('✗');
    const name = result.passed ? chalk.green(result.name) : chalk.red(result.name);
    
    console.log(`${status} ${name} (${result.duration}ms)`);
    
    if (!result.passed && result.failureReason) {
      console.log(chalk.red(`  └─ ${result.failureReason}`));
    }

    if (!result.passed && (result.output || result.error)) {
      console.log(chalk.gray('  Output:'));
      if (result.output) {
        console.log(chalk.gray(`    ${result.output.trim().replace(/\n/g, '\n    ')}`));
      }
      if (result.error) {
        console.log(chalk.red(`    ${result.error.trim().replace(/\n/g, '\n    ')}`));
      }
    }
  }

  private printSummary(): void {
    const passed = this.results.filter(r => r.passed).length;
    const failed = this.results.filter(r => !r.passed).length;
    const total = this.results.length;

    console.log('\n' + chalk.bold('Test Summary:'));
    console.log(chalk.green(`  ✓ ${passed} passed`));
    if (failed > 0) {
      console.log(chalk.red(`  ✗ ${failed} failed`));
    }
    console.log(chalk.gray(`  Total: ${total} tests`));
  }

  getResults(): TestResult[] {
    return this.results;
  }
}