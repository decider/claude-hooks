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
  constructor(private eventType: string) {}

  async loadConfig(): Promise<HookConfig> {
    const configPath = path.join(process.cwd(), '.claude', 'hooks', 'config.js');
    
    if (!fs.existsSync(configPath)) {
      logger.debug(this.eventType, 'No config.js found');
      return {};
    }
    
    try {
      // Simple require with cache clearing for fresh load
      delete require.cache[require.resolve(configPath)];
      return require(configPath);
    } catch (error: any) {
      logger.error(this.eventType, `Failed to load config: ${error.message}`);
      return {};
    }
  }

  async executeHook(hookName: string, input: ClaudeInput): Promise<void> {
    logger.info(this.eventType, `Running hook: ${hookName}`);
    
    return new Promise((resolve) => {
      const proc = spawn('npx', ['claude-code-hooks-cli', 'exec', hookName], {
        stdio: ['pipe', 'inherit', 'inherit'],
        env: { ...process.env, CLAUDE_HOOK_NAME: hookName }
      });

      proc.stdin.write(JSON.stringify(input));
      proc.stdin.end();
      
      proc.on('close', (code) => {
        if (code !== 0) {
          logger.warn(this.eventType, `Hook ${hookName} exited with code ${code}`);
        }
        resolve();
      });

      proc.on('error', (error) => {
        logger.error(this.eventType, `Hook ${hookName} error: ${error.message}`);
        resolve();
      });
    });
  }

  matchesPattern(text: string, pattern: string): boolean {
    try {
      return new RegExp(pattern).test(text);
    } catch {
      return false;
    }
  }

  matchesTool(toolName: string, matcher: string): boolean {
    return matcher.split('|').map(t => t.trim()).includes(toolName) || matcher === '*';
  }

  async readInput(): Promise<ClaudeInput> {
    return new Promise((resolve, reject) => {
      let data = '';
      process.stdin.on('data', chunk => data += chunk);
      process.stdin.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (error) {
          reject(new Error(`Failed to parse input: ${error}`));
        }
      });
    });
  }
}