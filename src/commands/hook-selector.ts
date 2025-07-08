import readline from 'readline';
import chalk from 'chalk';

export interface HookChoice {
  name: string;
  description: string;
  event: string;
  selected: boolean;
}

export class HookSelector {
  private choices: HookChoice[];
  private cursorPosition: number = 0;
  private rl: readline.Interface;
  private resolve: ((value: string[] | null) => void) | null = null;
  private onSave: ((selections: string[]) => Promise<void>) | null = null;

  constructor(choices: HookChoice[], onSave?: (selections: string[]) => Promise<void>) {
    this.choices = [...choices];
    this.onSave = onSave || null;
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
  }

  async run(): Promise<string[] | null> {
    return new Promise((resolve) => {
      this.resolve = resolve;
      this.render();
      this.setupKeyHandlers();
    });
  }

  private render() {
    console.clear();
    console.log(chalk.cyan('Hook Manager\n'));
    console.log(chalk.gray('↑/↓: Navigate  Enter: Toggle & Save  A: Select all  D: Deselect all  Q/Esc: Quit\n'));

    this.choices.forEach((choice, index) => {
      const isCurrentLine = index === this.cursorPosition;
      const checkbox = choice.selected ? chalk.green('◉') : '◯';
      const cursor = isCurrentLine ? chalk.cyan('❯') : ' ';
      const name = choice.name.padEnd(30);
      const event = `(${choice.event})`;
      
      // Highlight current line with bold and cyan color
      if (isCurrentLine) {
        console.log(`${cursor}${checkbox} ${chalk.bold.cyan(name)} ${chalk.bold.cyan(event)}`);
      } else {
        console.log(`${cursor}${checkbox} ${name} ${chalk.gray(event)}`);
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
        // Ctrl+C, Escape, or Q - quit without saving
        this.cleanup();
        if (this.resolve) {
          this.resolve(null); // Return null to indicate cancellation
        }
        return;
      }

      if (key === '\r') {
        // Enter - toggle current item and save
        this.choices[this.cursorPosition].selected = !this.choices[this.cursorPosition].selected;
        
        if (this.onSave) {
          const selected = this.choices.filter(c => c.selected).map(c => c.name);
          await this.onSave(selected);
          this.render();
          console.log(chalk.gray('\nSaved'));
          await new Promise(resolve => setTimeout(resolve, 500));
        } else {
          this.render();
        }
      } else if (key === '\u001b[A' || key === 'k') {
        // Up arrow or k
        this.cursorPosition = Math.max(0, this.cursorPosition - 1);
        this.render();
      } else if (key === '\u001b[B' || key === 'j') {
        // Down arrow or j
        this.cursorPosition = Math.min(this.choices.length - 1, this.cursorPosition + 1);
        this.render();
      } else if (key.toLowerCase() === 'a') {
        // A - select all
        this.choices.forEach(choice => choice.selected = true);
        if (this.onSave) {
          const selected = this.choices.filter(c => c.selected).map(c => c.name);
          await this.onSave(selected);
          this.render();
          console.log(chalk.gray('\nSaved'));
          await new Promise(resolve => setTimeout(resolve, 500));
        } else {
          this.render();
        }
      } else if (key.toLowerCase() === 'd') {
        // D - deselect all
        this.choices.forEach(choice => choice.selected = false);
        if (this.onSave) {
          await this.onSave([]);
          this.render();
          console.log(chalk.gray('\nSaved'));
          await new Promise(resolve => setTimeout(resolve, 500));
        } else {
          this.render();
        }
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