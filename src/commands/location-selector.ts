import readline from 'readline';
import chalk from 'chalk';
import { SettingsLocation } from '../types.js';

export interface LocationChoice {
  path: string;
  display: string;
  description: string;
  hookCount: number;
  value: string;
}

export class LocationSelector {
  private choices: LocationChoice[];
  private cursorPosition: number = 0;
  private rl: readline.Interface;
  private resolve: ((value: string | null) => void) | null = null;
  private showStats: boolean;
  private stats: Array<{ name: string; count: number; relativeTime: string }>;

  constructor(choices: LocationChoice[], showStats: boolean = false, stats: Array<{ name: string; count: number; relativeTime: string }> = []) {
    this.choices = [...choices];
    this.showStats = showStats;
    this.stats = stats;
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
  }

  async run(): Promise<string | null> {
    return new Promise((resolve) => {
      this.resolve = resolve;
      this.render();
      this.setupKeyHandlers();
    });
  }

  private render() {
    console.clear();
    console.log(chalk.cyan('Claude Hooks Manager\n'));
    
    // Show stats if available
    if (this.showStats && this.stats.length > 0) {
      console.log(chalk.gray('─'.repeat(50)));
      console.log(chalk.gray('Hook Name'.padEnd(30) + 'Calls'.padEnd(10) + 'Last Called'));
      console.log(chalk.gray('─'.repeat(50)));
      
      this.stats.forEach(stat => {
        const name = stat.name.padEnd(30);
        const calls = stat.count.toString().padEnd(10);
        const lastCall = stat.relativeTime;
        console.log(`${name}${calls}${lastCall}`);
      });
      console.log(chalk.gray('─'.repeat(50)));
      console.log();
    }
    
    console.log(chalk.gray('↑/↓: Navigate  Enter: Select  Q/Esc: Exit\n'));

    this.choices.forEach((choice, index) => {
      const isCurrentLine = index === this.cursorPosition;
      const cursor = isCurrentLine ? chalk.cyan('❯') : ' ';
      
      let line = '';
      if (choice.value === 'separator') {
        line = chalk.gray('──────────────');
      } else if (choice.value === 'exit') {
        line = chalk.red('✕ Exit');
      } else if (choice.value === 'view-logs' || choice.value === 'tail-logs') {
        line = choice.display;
      } else {
        // Regular location choice
        const hookInfo = `(${choice.hookCount} ${choice.hookCount === 1 ? 'hook' : 'hooks'})`;
        const mainText = `${choice.display} ${hookInfo} - ${choice.description}`;
        line = mainText;
      }
      
      // Highlight current line
      if (isCurrentLine && choice.value !== 'separator') {
        console.log(`${cursor}${chalk.bold.cyan(line)}`);
      } else {
        console.log(`${cursor}${line}`);
      }
    });
  }

  private setupKeyHandlers() {
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(true);
    }
    
    process.stdin.resume();
    process.stdin.setEncoding('utf8');
    
    process.stdin.on('data', async (key: string) => {
      // Handle special keys
      if (key === '\u0003' || key === '\u001b' || key.toLowerCase() === 'q') {
        // Ctrl+C, Escape, or Q - exit
        this.cleanup();
        if (this.resolve) {
          this.resolve('exit');
        }
        return;
      }

      if (key === '\r') {
        // Enter - select current item
        const choice = this.choices[this.cursorPosition];
        if (choice.value !== 'separator') {
          this.cleanup();
          if (this.resolve) {
            this.resolve(choice.value);
          }
        }
      } else if (key === '\u001b[A' || key === 'k') {
        // Up arrow or k - skip separators
        do {
          this.cursorPosition = Math.max(0, this.cursorPosition - 1);
        } while (this.cursorPosition > 0 && this.choices[this.cursorPosition].value === 'separator');
        this.render();
      } else if (key === '\u001b[B' || key === 'j') {
        // Down arrow or j - skip separators
        do {
          this.cursorPosition = Math.min(this.choices.length - 1, this.cursorPosition + 1);
        } while (this.cursorPosition < this.choices.length - 1 && this.choices[this.cursorPosition].value === 'separator');
        this.render();
      }
    });
  }

  private cleanup() {
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(false);
    }
    process.stdin.pause();
    process.stdin.removeAllListeners('data');
    this.rl.close();
  }
}