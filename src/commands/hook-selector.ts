import readline from 'readline';
import chalk from 'chalk';

export interface HookChoice {
  name: string;
  description: string;
  event: string;
  selected: boolean;
  source?: 'built-in' | 'project' | 'custom';
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
      
      // Determine source label
      let sourceLabel = '';
      if (choice.source === 'project') {
        sourceLabel = chalk.blue('[project]');
      } else if (choice.source === 'custom') {
        sourceLabel = chalk.dim('[custom]');
      } else if (choice.source !== 'built-in') {
        // Legacy custom hook detection for backwards compatibility
        const isCustom = !choice.description.startsWith('TypeScript') && 
                         !choice.description.startsWith('Code linting') &&
                         !choice.description.startsWith('Run test') &&
                         !choice.description.startsWith('Prevents') &&
                         !choice.description.startsWith('Enforces') &&
                         !choice.description.startsWith('System');
        if (isCustom) {
          sourceLabel = chalk.dim('[custom]');
        }
      }
      
      // Highlight current line with bold and cyan color
      if (isCurrentLine) {
        const nameStr = sourceLabel ? `${chalk.bold.cyan(name)} ${sourceLabel}` : chalk.bold.cyan(name);
        console.log(`${cursor}${checkbox} ${nameStr} ${chalk.bold.cyan(event)}`);
      } else {
        const nameStr = sourceLabel ? `${name} ${sourceLabel}` : name;
        console.log(`${cursor}${checkbox} ${nameStr} ${chalk.gray(event)}`);
      }
    });
    
    // Show descriptions for current selection
    console.log('\n' + chalk.gray('─'.repeat(80)) + '\n');
    const currentChoice = this.choices[this.cursorPosition];
    if (currentChoice) {
      console.log(chalk.white('Description: ') + chalk.gray(currentChoice.description));
    }
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