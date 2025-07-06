import { spawn } from 'child_process';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { existsSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export async function exec(hookName: string): Promise<void> {
  // Resolve hook path
  const hookPath = join(__dirname, '../../hooks', `${hookName}.sh`);
  
  if (!existsSync(hookPath)) {
    console.error(`Error: Hook '${hookName}' not found`);
    process.exit(1);
  }

  // Read stdin for hook input
  let input = '';
  process.stdin.setEncoding('utf8');
  
  // Collect all stdin
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  // Spawn the hook process
  const hookProcess = spawn('bash', [hookPath], {
    stdio: ['pipe', 'inherit', 'inherit'],
    env: { ...process.env }
  });

  // Write input to hook's stdin
  hookProcess.stdin.write(input);
  hookProcess.stdin.end();

  // Wait for hook to complete
  hookProcess.on('exit', (code) => {
    process.exit(code || 0);
  });

  hookProcess.on('error', (err) => {
    console.error(`Error executing hook: ${err.message}`);
    process.exit(1);
  });
}