import readline from 'readline';
import chalk from 'chalk';
import { writeFileSync, existsSync, mkdirSync, readFileSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

export interface HookChoice {
  name: string;
  description: string;
  event: string;
  selected: boolean;
  source?: 'built-in' | 'project' | 'custom';
}

// Helper function to save API key
async function saveApiKey(apiKey: string, location: 'global' | 'project'): Promise<void> {
  const envPath = location === 'global' 
    ? join(homedir(), '.claude', '.env')
    : join(process.cwd(), '.env');
    
  const envDir = location === 'global'
    ? join(homedir(), '.claude')
    : process.cwd();
    
  // Create directory if needed
  if (!existsSync(envDir)) {
    mkdirSync(envDir, { recursive: true });
  }
  
  // Check if .env file exists and has content
  let envContent = '';
  if (existsSync(envPath)) {
    envContent = readFileSync(envPath, 'utf-8');
    // Remove existing ANTHROPIC_API_KEY if present
    envContent = envContent.split('\n')
      .filter(line => !line.startsWith('ANTHROPIC_API_KEY='))
      .join('\n');
    if (envContent && !envContent.endsWith('\n')) {
      envContent += '\n';
    }
  }
  
  // Add the new API key
  envContent += `ANTHROPIC_API_KEY=${apiKey}\n`;
  
  // Write the file
  writeFileSync(envPath, envContent, { mode: 0o600 }); // Secure permissions
}

export class HookSelector {
  private choices: HookChoice[];
  private cursorPosition: number = 0;
  private rl: readline.Interface;
  private resolve: ((value: string[] | null) => void) | null = null;
  private onSave: ((selections: string[]) => Promise<any>) | null = null;

  constructor(choices: HookChoice[], onSave?: (selections: string[]) => Promise<any>) {
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
          const result = await this.onSave(selected);
          this.render();
          
          // Check if any hooks were blocked due to missing API key
          if (result && result.blockedHooks && result.blockedHooks.length > 0) {
            console.log(chalk.yellow('\n⚠️  API Key Required'));
            console.log(chalk.gray(`\nThe ${result.blockedHooks.join(', ')} hook(s) require an Anthropic API key.`));
            console.log(chalk.gray('Get your key at: ') + chalk.cyan('https://console.anthropic.com/settings/keys'));
            console.log('');
            console.log(chalk.white('Options:'));
            console.log(chalk.gray('  1. Paste your API key now (starts with sk-ant-)'));
            console.log(chalk.gray('  2. Press Esc to cancel and set it up manually'));
            console.log(chalk.gray('     • Add to ~/.claude/.env (all projects)'));
            console.log(chalk.gray('     • Add to .env (current project)'));
            console.log(chalk.gray('     Format: ANTHROPIC_API_KEY=sk-ant-...'));
            console.log('');
            console.log(chalk.cyan('Paste API key or press Esc: '));
            
            // Collect API key input
            let apiKeyBuffer = '';
            const apiKeyResult = await new Promise<string | null>(resolve => {
              const handler = (key: string) => {
                if (key === '\u001b') { // Esc
                  process.stdin.removeListener('data', handler);
                  resolve(null);
                } else if (key === '\r') { // Enter
                  process.stdin.removeListener('data', handler);
                  resolve(apiKeyBuffer.trim());
                } else if (key === '\u007f' || key === '\b') { // Backspace
                  if (apiKeyBuffer.length > 0) {
                    apiKeyBuffer = apiKeyBuffer.slice(0, -1);
                    process.stdout.write('\b \b');
                  }
                } else if (key.charCodeAt(0) >= 32) { // Printable characters
                  apiKeyBuffer += key;
                  process.stdout.write('*'); // Show asterisks for security
                }
              };
              process.stdin.on('data', handler);
            });
            
            if (apiKeyResult && apiKeyResult.startsWith('sk-ant-')) {
              // Save the API key
              const saveLocation = apiKeyResult.length > 50 ? 'global' : 'global'; // Always save to global for now
              await saveApiKey(apiKeyResult, saveLocation);
              console.log(chalk.green(`\n✓ API key saved to ~/.claude/.env`));
              console.log(chalk.gray('Press Enter to continue...'));
              await new Promise(resolve => {
                const handler = (key: string) => {
                  if (key === '\r') {
                    process.stdin.removeListener('data', handler);
                    resolve(undefined);
                  }
                };
                process.stdin.on('data', handler);
              });
            } else if (apiKeyResult) {
              console.log(chalk.red('\n✗ Invalid API key format (must start with sk-ant-)'));
              console.log(chalk.gray('Press Enter to continue...'));
              await new Promise(resolve => {
                const handler = (key: string) => {
                  if (key === '\r') {
                    process.stdin.removeListener('data', handler);
                    resolve(undefined);
                  }
                };
                process.stdin.on('data', handler);
              });
            } else {
              console.log(chalk.yellow('\nCancelled. Set up your API key manually to use this hook.'));
            }
            
            this.render();
          } else {
            console.log(chalk.gray('\nSaved'));
            await new Promise(resolve => setTimeout(resolve, 500));
          }
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