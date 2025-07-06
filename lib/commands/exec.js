import { spawn } from 'child_process';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { existsSync } from 'fs';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
export async function exec(hookName) {
    // Resolve hook path - try multiple locations
    const possiblePaths = [
        join(__dirname, '../../hooks', `${hookName}.sh`),
        join(process.cwd(), 'hooks', `${hookName}.sh`),
        join(process.cwd(), 'claude', 'hooks', `${hookName}.sh`),
        join(process.cwd(), '.claude', 'hooks', `${hookName}.sh`)
    ];
    let hookPath = null;
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
        // Capture both stdout and stderr for better error reporting
        const hookProcess = spawn('bash', [hookPath], {
            stdio: ['pipe', 'pipe', 'pipe'],
            env: {
                ...process.env,
                HOOK_NAME: hookName,
                HOOK_START_TIME: startTime.toString()
            }
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
            if (code !== 0) {
                // Enhanced error reporting
                console.error(`\n--- Hook Execution Summary ---`);
                console.error(`Hook: ${hookName}`);
                console.error(`Exit Code: ${code}`);
                console.error(`Duration: ${duration}ms`);
                console.error(`Working Directory: ${process.cwd()}`);
                console.error(`Hook Path: ${hookPath}`);
                if (stdout.trim()) {
                    console.error(`\nStdout Output:`);
                    console.error(stdout.trim());
                }
                if (stderr.trim()) {
                    console.error(`\nStderr Output:`);
                    console.error(stderr.trim());
                }
                else {
                    console.error(`\nNo stderr output (this may indicate the hook is not properly reporting errors)`);
                }
                console.error(`\n--- End Hook Summary ---\n`);
            }
            process.exit(code || 0);
        });
        hookProcess.on('error', (err) => {
            console.error(`\n--- Hook Execution Error ---`);
            console.error(`Hook: ${hookName}`);
            console.error(`Error: ${err.message}`);
            console.error(`Working Directory: ${process.cwd()}`);
            console.error(`Hook Path: ${hookPath}`);
            console.error(`--- End Hook Error ---\n`);
            process.exit(1);
        });
        // Set a timeout for hook execution (5 minutes)
        const hookTimeout = setTimeout(() => {
            console.error(`\n--- Hook Timeout ---`);
            console.error(`Hook '${hookName}' timed out after 5 minutes`);
            console.error(`Hook Path: ${hookPath}`);
            console.error(`--- End Hook Timeout ---\n`);
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
    }
    catch (err) {
        clearTimeout(stdinTimeout);
        if (isDebug) {
            console.error(`[DEBUG] Error reading stdin: ${err}`);
        }
        processHook();
    }
}
//# sourceMappingURL=exec.js.map