import { spawn } from 'child_process';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { existsSync, appendFileSync, mkdirSync } from 'fs';
import { homedir } from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Local logging configuration
const LOG_DIR = join(homedir(), '.local', 'share', 'claude-hooks', 'logs');
const LOG_FILE = join(LOG_DIR, 'hooks.log');

function ensureLogDir() {
  try {
    mkdirSync(LOG_DIR, { recursive: true });
  } catch (err) {
    // Ignore errors
  }
}

function logToFile(level: string, hookName: string, message: string) {
  try {
    ensureLogDir();
    const timestamp = new Date().toISOString().replace('T', ' ').split('.')[0];
    const logEntry = `[${timestamp}] [${level}] [${hookName}] ${message}\n`;
    appendFileSync(LOG_FILE, logEntry);
  } catch (err) {
    // Silently fail - don't interfere with hook execution
  }
}

function formatClaudeError(hookName: string, code: number | null, stderr: string, stdout: string, hookPath: string, duration: number): string {
  // Ultra-compact error message for Claude
  let message = `Hook '${hookName}' failed (exit ${code})`;
  
  // Analyze error and add inline action
  if (stderr.includes('Usage:') || stderr.includes('usage:')) {
    message += ' - Check hook arguments';
  } else if (stderr.includes('command not found') || stderr.includes('not found')) {
    message += ' - Install missing dependencies';
  } else if (stderr.includes('permission denied')) {
    message += ' - Check file permissions';
  } else if (stderr.includes('npm') || stderr.includes('node')) {
    message += ' - Run npm install';
  }
  
  // Add stderr inline if short enough
  if (stderr.trim() && stderr.length < 200) {
    message += `: ${stderr.trim().replace(/\n/g, ' ')}`;
  }
  
  return message;
}

export async function exec(hookName: string, options?: any): Promise<void> {
  // Check if hookName is actually a direct command/path
  let hookPath: string | null = null;
  
  // If hookName looks like a path or command, use it directly
  if (hookName.includes('/') || hookName.includes('.')) {
    // Resolve relative paths from current working directory
    hookPath = hookName.startsWith('/') ? hookName : join(process.cwd(), hookName);
    
    // Check if the file exists
    if (!existsSync(hookPath)) {
      console.error(`Error: Hook command '${hookName}' not found at ${hookPath}`);
      process.exit(1);
    }
  } else {
    // Standard hook name - try multiple locations
    const possiblePaths = [
      join(__dirname, '../../hooks', `${hookName}.sh`),
      join(process.cwd(), 'hooks', `${hookName}.sh`),
      join(process.cwd(), '.claude', 'hooks', `${hookName}.sh`)
    ];
    
    for (const path of possiblePaths) {
      if (existsSync(path)) {
        hookPath = path;
        break;
      }
    }
    
    if (!hookPath) {
      console.error(`Error: Hook '${hookName}' not found in any of these locations:`);
      possiblePaths.forEach(path => console.error(`  - ${path}`));
      process.exit(1);
    }
  }

  const startTime = Date.now();
  const isDebug = process.env.CLAUDE_LOG_LEVEL === 'DEBUG';
  
  if (isDebug) {
    console.error(`[DEBUG] Executing hook: ${hookName}`);
    console.error(`[DEBUG] Hook path: ${hookPath}`);
    console.error(`[DEBUG] Working directory: ${process.cwd()}`);
  }

  // Read stdin for hook input with timeout
  let input = '';
  process.stdin.setEncoding('utf8');
  
  const processHook = () => {
    // Log hook start to local file
    logToFile('INFO', hookName, 'Hook started');
    
    // Prepare environment variables with filtering options
    const hookEnv: Record<string, string> = {
      ...process.env,
      HOOK_NAME: hookName,
      HOOK_START_TIME: startTime.toString()
    };

    // Add filtering options if provided
    if (options?.files) {
      hookEnv.HOOK_FILES = options.files;
    }
    if (options?.exclude) {
      hookEnv.HOOK_EXCLUDE = options.exclude;
    }
    if (options?.include) {
      hookEnv.HOOK_INCLUDE = options.include;
    }

    // Capture both stdout and stderr for better error reporting
    const hookProcess = spawn('bash', [hookPath!], {
      stdio: ['pipe', 'pipe', 'pipe'],
      env: hookEnv
    });

    let stdout = '';
    let stderr = '';

    // Collect outputs
    hookProcess.stdout.on('data', (data) => {
      const output = data.toString();
      stdout += output;
      process.stdout.write(output);
    });

    hookProcess.stderr.on('data', (data) => {
      const output = data.toString();
      stderr += output;
      process.stderr.write(output);
    });

    // Write input to hook's stdin
    if (input) {
      hookProcess.stdin.write(input);
    }
    hookProcess.stdin.end();

    // Wait for hook to complete
    hookProcess.on('exit', (code) => {
      const duration = Date.now() - startTime;
      
      if (isDebug) {
        console.error(`[DEBUG] Hook '${hookName}' completed in ${duration}ms with exit code ${code}`);
      }
      
      // Log to local file
      if (code === 0) {
        logToFile('INFO', hookName, `Hook completed successfully (exit code: 0)`);
      } else {
        logToFile('ERROR', hookName, `Hook failed (exit code: ${code})`);
        if (stderr.trim()) {
          logToFile('ERROR', hookName, `Error output: ${stderr.trim()}`);
        }
      }
      
      if (code !== 0) {
        // Concise error reporting for Claude
        const errorMessage = formatClaudeError(hookName, code, stderr, stdout, hookPath!, duration);
        console.error(errorMessage);
      }
      
      process.exit(code || 0);
    });

    hookProcess.on('error', (err) => {
      // Log to local file
      logToFile('ERROR', hookName, `Hook execution error: ${err.message}`);
      
      // Ultra-compact error for Claude
      console.error(`Hook '${hookName}' execution error: ${err.message} - Check file exists and is executable`);
      
      process.exit(1);
    });

    // Set a timeout for hook execution (5 minutes)
    const hookTimeout = setTimeout(() => {
      // Log to local file
      logToFile('ERROR', hookName, 'Hook timed out after 5 minutes');
      
      // Ultra-compact error for Claude
      console.error(`Hook '${hookName}' timed out (5min) - May be stuck or waiting for input`);
      
      hookProcess.kill('SIGKILL');
      process.exit(124); // Timeout exit code
    }, 5 * 60 * 1000);

    hookProcess.on('exit', () => {
      clearTimeout(hookTimeout);
    });
  };

  // Set a timeout for stdin collection
  const stdinTimeout = setTimeout(() => {
    if (isDebug) {
      console.error(`[DEBUG] stdin timeout after 5 seconds for hook '${hookName}'`);
    }
    processHook();
  }, 5000);
  
  try {
    // Collect all stdin
    for await (const chunk of process.stdin) {
      input += chunk.toString();
    }
    clearTimeout(stdinTimeout);
    processHook();
  } catch (err) {
    clearTimeout(stdinTimeout);
    if (isDebug) {
      console.error(`[DEBUG] Error reading stdin: ${err}`);
    }
    processHook();
  }
}