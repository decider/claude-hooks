import { spawn } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { logger } from '../testing/logger.js';

export interface HookConfig {
  preToolUse?: {
    [matcher: string]: {
      [pattern: string]: string[];
    };
  };
  postToolUse?: {
    [matcher: string]: string[];
  };
  stop?: string[];
  preWrite?: {
    [pattern: string]: string[];
  };
  postWrite?: {
    [pattern: string]: string[];
  };
}

export interface ClaudeInput {
  tool_name: string;
  tool_input: any;
  hook_event_name: string;
}

export class HookEntryPoint {
  private configPath: string;
  private config: HookConfig | null = null;

  constructor(private eventType: string) {
    // Look for config in multiple locations
    const configPaths = [
      path.join(process.cwd(), '.claude', 'hooks', 'config.js'),
      path.join(process.cwd(), '.claude', 'hooks.config.js'),
      path.join(process.cwd(), 'claude', 'hooks', 'config.js'),
    ];
    
    this.configPath = configPaths.find(p => fs.existsSync(p)) || configPaths[0];
  }

  async loadConfig(): Promise<HookConfig> {
    try {
      // Check if config exists
      if (!fs.existsSync(this.configPath)) {
        logger.debug(this.eventType, `No config found at ${this.configPath}, using empty config`);
        return {};
      }
      
      const resolvedPath = path.resolve(this.configPath);
      
      // Read the config file
      const configContent = fs.readFileSync(resolvedPath, 'utf-8');
      
      // Create a CommonJS-like environment to evaluate the config
      const module = { exports: {} };
      const exports = module.exports;
      
      // Evaluate the config in a function context
      const evalFunc = new Function('module', 'exports', configContent);
      evalFunc(module, exports);
      
      this.config = module.exports;
      
      return this.config || {};
    } catch (error: any) {
      // If loading fails, return empty config
      logger.error(this.eventType, `Failed to load config: ${error.message}`);
      return {};
    }
  }

  async executeHook(hookName: string, input: ClaudeInput): Promise<void> {
    const startTime = Date.now();
    
    logger.hookStart(hookName, this.eventType, {
      tool: input.tool_name,
      matcher: process.env.CLAUDE_HOOK_MATCHER,
      pattern: process.env.CLAUDE_HOOK_PATTERN
    });

    return new Promise((resolve) => {
      const hookProcess = spawn('npx', ['claude-code-hooks-cli', 'exec', hookName], {
        stdio: ['pipe', 'inherit', 'inherit'],
        env: {
          ...process.env,
          CLAUDE_HOOK_NAME: hookName,
          CLAUDE_HOOK_EVENT: this.eventType
        }
      });

      // Pass input to hook via stdin
      hookProcess.stdin.write(JSON.stringify(input));
      hookProcess.stdin.end();

      hookProcess.on('close', (code) => {
        const duration = Date.now() - startTime;
        const success = code === 0;
        
        logger.hookEnd(hookName, this.eventType, duration, success, {
          exitCode: code
        });
        
        resolve();
      });

      hookProcess.on('error', (error) => {
        const duration = Date.now() - startTime;
        logger.hookEnd(hookName, this.eventType, duration, false, {
          error: error.message
        });
        resolve();
      });
    });
  }

  matchesPattern(text: string, pattern: string): boolean {
    try {
      const regex = new RegExp(pattern);
      return regex.test(text);
    } catch (error) {
      logger.error(this.eventType, `Invalid regex pattern: ${pattern}`);
      return false;
    }
  }

  matchesTool(toolName: string, matcher: string): boolean {
    const tools = matcher.split('|').map(t => t.trim());
    return tools.includes(toolName) || matcher === '*';
  }

  async readInput(): Promise<ClaudeInput> {
    return new Promise((resolve, reject) => {
      let data = '';
      
      process.stdin.on('data', (chunk) => {
        data += chunk;
      });
      
      process.stdin.on('end', () => {
        try {
          const input = JSON.parse(data);
          resolve(input);
        } catch (error) {
          reject(new Error(`Failed to parse input: ${error}`));
        }
      });
      
      process.stdin.on('error', reject);
    });
  }
}