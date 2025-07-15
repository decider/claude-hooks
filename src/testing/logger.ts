import * as fs from 'fs';
import * as path from 'path';
import chalk from 'chalk';

export interface LogEntry {
  timestamp: string;
  level: 'debug' | 'info' | 'warn' | 'error' | 'success';
  event?: string;
  hook?: string;
  message: string;
  data?: any;
  duration?: number;
}

export class HookLogger {
  private static instance: HookLogger;
  private logFile: string;
  private logStream?: fs.WriteStream;
  private verbose: boolean = false;
  private testMode: boolean = false;
  private logs: LogEntry[] = [];

  private constructor() {
    const logDir = path.join(process.cwd(), '.claude', 'logs');
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }
    this.logFile = path.join(logDir, `hooks-${new Date().toISOString().split('T')[0]}.log`);
  }

  static getInstance(): HookLogger {
    if (!HookLogger.instance) {
      HookLogger.instance = new HookLogger();
    }
    return HookLogger.instance;
  }

  setVerbose(verbose: boolean): void {
    this.verbose = verbose;
  }

  setTestMode(testMode: boolean): void {
    this.testMode = testMode;
    if (testMode) {
      this.logs = [];
    }
  }

  private formatMessage(entry: LogEntry): string {
    const timestamp = new Date(entry.timestamp).toISOString();
    let message = `[${timestamp}] [${entry.level.toUpperCase()}]`;
    
    if (entry.event) {
      message += ` [${entry.event}]`;
    }
    
    if (entry.hook) {
      message += ` [${entry.hook}]`;
    }
    
    message += ` ${entry.message}`;
    
    if (entry.duration !== undefined) {
      message += ` (${entry.duration}ms)`;
    }
    
    if (entry.data && this.verbose) {
      message += `\n${JSON.stringify(entry.data, null, 2)}`;
    }
    
    return message;
  }

  private writeToFile(entry: LogEntry): void {
    if (!this.logStream) {
      this.logStream = fs.createWriteStream(this.logFile, { flags: 'a' });
    }
    this.logStream.write(this.formatMessage(entry) + '\n');
  }

  private log(entry: LogEntry): void {
    if (this.testMode) {
      this.logs.push(entry);
    }

    this.writeToFile(entry);

    if (this.verbose || entry.level === 'error' || entry.level === 'warn') {
      const coloredMessage = this.getColoredMessage(entry);
      console.log(coloredMessage);
    }
  }

  private getColoredMessage(entry: LogEntry): string {
    const prefix = `[${entry.hook || 'system'}]`;
    const message = entry.message;
    
    switch (entry.level) {
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

  debug(hook: string, message: string, data?: any): void {
    this.log({
      timestamp: new Date().toISOString(),
      level: 'debug',
      hook,
      message,
      data
    });
  }

  info(hook: string, message: string, data?: any): void {
    this.log({
      timestamp: new Date().toISOString(),
      level: 'info',
      hook,
      message,
      data
    });
  }

  warn(hook: string, message: string, data?: any): void {
    this.log({
      timestamp: new Date().toISOString(),
      level: 'warn',
      hook,
      message,
      data
    });
  }

  error(hook: string, message: string, data?: any): void {
    this.log({
      timestamp: new Date().toISOString(),
      level: 'error',
      hook,
      message,
      data
    });
  }

  success(hook: string, message: string, data?: any): void {
    this.log({
      timestamp: new Date().toISOString(),
      level: 'success',
      hook,
      message,
      data
    });
  }

  hookStart(hook: string, event: string, data?: any): void {
    this.log({
      timestamp: new Date().toISOString(),
      level: 'info',
      event,
      hook,
      message: 'Hook started',
      data
    });
  }

  hookEnd(hook: string, event: string, duration: number, success: boolean, data?: any): void {
    this.log({
      timestamp: new Date().toISOString(),
      level: success ? 'success' : 'error',
      event,
      hook,
      message: success ? 'Hook completed successfully' : 'Hook failed',
      duration,
      data
    });
  }

  getTestLogs(): LogEntry[] {
    return this.logs;
  }

  clearTestLogs(): void {
    this.logs = [];
  }

  close(): void {
    if (this.logStream) {
      this.logStream.end();
      this.logStream = undefined;
    }
  }
}

export const logger = HookLogger.getInstance();