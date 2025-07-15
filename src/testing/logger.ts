import chalk from 'chalk';

export class HookLogger {
  private static instance: HookLogger;
  private verbose: boolean = process.env.VERBOSE === 'true' || process.env.DEBUG === 'true';

  private constructor() {}

  static getInstance(): HookLogger {
    if (!HookLogger.instance) {
      HookLogger.instance = new HookLogger();
    }
    return HookLogger.instance;
  }

  setVerbose(verbose: boolean): void {
    this.verbose = verbose;
  }

  private getColoredMessage(level: string, hook: string, message: string): string {
    const prefix = `[${hook}]`;
    
    switch (level) {
      case 'debug':
        return chalk.gray(`${prefix} ${message}`);
      case 'info':
        return chalk.blue(`${prefix} ${message}`);
      case 'warn':
        return chalk.yellow(`${prefix} ${message}`);
      case 'error':
        return chalk.red(`${prefix} ${message}`);
      case 'success':
        return chalk.green(`${prefix} ${message}`);
      default:
        return `${prefix} ${message}`;
    }
  }

  debug(hook: string, message: string): void {
    if (this.verbose) {
      console.log(this.getColoredMessage('debug', hook, message));
    }
  }

  info(hook: string, message: string): void {
    if (this.verbose) {
      console.log(this.getColoredMessage('info', hook, message));
    }
  }

  warn(hook: string, message: string): void {
    console.log(this.getColoredMessage('warn', hook, message));
  }

  error(hook: string, message: string): void {
    console.log(this.getColoredMessage('error', hook, message));
  }

  success(hook: string, message: string): void {
    if (this.verbose) {
      console.log(this.getColoredMessage('success', hook, message));
    }
  }

  hookStart(hook: string, event: string): void {
    if (this.verbose) {
      console.log(this.getColoredMessage('info', hook, `${event} hook started`));
    }
  }

  hookEnd(hook: string, event: string, duration: number, success: boolean): void {
    if (this.verbose) {
      const level = success ? 'success' : 'error';
      const status = success ? 'completed' : 'failed';
      console.log(this.getColoredMessage(level, hook, `${event} hook ${status} (${duration}ms)`));
    }
  }
}

export const logger = HookLogger.getInstance();