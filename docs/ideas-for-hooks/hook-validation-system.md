# Hook Validation System

## Overview

A comprehensive validation system that ensures hook files are properly structured, executable, and safe before they can be registered in any Claude configuration. This system provides both a CLI command for manual validation and automatic validation hooks that prevent invalid configurations from being saved.

## Problem Statement

Invalid hooks can cause:
- Silent failures that are hard to debug
- Security vulnerabilities from malformed scripts
- Configuration corruption
- Unexpected Claude behavior
- Wasted time troubleshooting hook issues
- Inconsistent hook behavior across environments

## Core Components

### 1. Hook Validator Engine
```typescript
interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
  warnings: ValidationWarning[];
  metadata: HookMetadata;
  securityScore: number;
  suggestions: string[];
}

interface ValidationError {
  code: string;
  message: string;
  line?: number;
  column?: number;
  severity: 'error' | 'critical';
  fix?: string;
}

interface HookMetadata {
  type: HookType;
  language: 'javascript' | 'typescript' | 'bash' | 'python';
  dependencies: string[];
  exitCodes: number[];
  timeout: number;
  permissions: string[];
}
```

### 2. Validation Rules
```typescript
enum ValidationRule {
  // Structure validation
  VALID_SHEBANG = "valid-shebang",
  PROPER_EXPORTS = "proper-exports",
  EXIT_CODE_HANDLING = "exit-code-handling",
  ERROR_HANDLING = "error-handling",
  
  // Security validation
  NO_EVAL_USAGE = "no-eval",
  NO_PROCESS_EXIT = "no-process-exit",
  NO_FILESYSTEM_ABUSE = "no-fs-abuse",
  NO_NETWORK_REQUESTS = "no-network-requests",
  
  // Performance validation  
  TIMEOUT_COMPLIANCE = "timeout-compliance",
  MEMORY_LIMITS = "memory-limits",
  NO_INFINITE_LOOPS = "no-infinite-loops",
  
  // Compatibility validation
  CLAUDE_API_COMPATIBLE = "claude-api-compatible",
  PARAMETER_VALIDATION = "parameter-validation",
  RETURN_TYPE_CORRECT = "return-type-correct"
}
```

## Implementation

### CLI Validation Command
```bash
# Validate a single hook file
claude-hooks validate ./hooks/pre-write.js

# Validate all hooks in a directory
claude-hooks validate ./claude/hooks/

# Validate with verbose output
claude-hooks validate ./hooks/my-hook.ts --verbose

# Validate and auto-fix issues
claude-hooks validate ./hooks/broken-hook.js --fix
```

### Validator Implementation
```typescript
// src/commands/validate.ts
import { parse } from '@babel/parser';
import { traverse } from '@babel/traverse';

export async function validateHook(hookPath: string): Promise<ValidationResult> {
  const result: ValidationResult = {
    valid: true,
    errors: [],
    warnings: [],
    metadata: {} as HookMetadata,
    securityScore: 100,
    suggestions: []
  };
  
  try {
    // Read hook file
    const content = await fs.readFile(hookPath, 'utf8');
    const ext = path.extname(hookPath);
    
    // Detect language and validate accordingly
    if (ext === '.js' || ext === '.ts') {
      await validateJavaScriptHook(content, result);
    } else if (ext === '.sh') {
      await validateBashHook(content, result);
    } else if (ext === '.py') {
      await validatePythonHook(content, result);
    } else {
      result.errors.push({
        code: 'UNSUPPORTED_LANGUAGE',
        message: `Unsupported file type: ${ext}`,
        severity: 'error'
      });
    }
    
    // Common validations
    await validateSecurity(content, result);
    await validatePerformance(content, result);
    await validateClaudeCompatibility(hookPath, result);
    
  } catch (error) {
    result.valid = false;
    result.errors.push({
      code: 'PARSE_ERROR',
      message: `Failed to parse hook: ${error.message}`,
      severity: 'critical'
    });
  }
  
  // Set overall validity
  result.valid = result.errors.length === 0;
  
  return result;
}
```

### JavaScript/TypeScript Validation
```typescript
async function validateJavaScriptHook(
  content: string, 
  result: ValidationResult
): Promise<void> {
  // Parse AST
  const ast = parse(content, {
    sourceType: 'module',
    plugins: ['typescript']
  });
  
  // Check for required exports
  let hasValidExport = false;
  let hasProperSignature = false;
  
  traverse(ast, {
    ExportNamedDeclaration(path) {
      const declaration = path.node.declaration;
      if (declaration?.type === 'FunctionDeclaration') {
        hasValidExport = true;
        
        // Validate function signature
        const params = declaration.params;
        const hookType = detectHookType(declaration.id.name);
        
        if (!validateParameters(params, hookType)) {
          result.errors.push({
            code: 'INVALID_PARAMETERS',
            message: `Hook function has incorrect parameters for ${hookType}`,
            line: declaration.loc?.start.line,
            severity: 'error',
            fix: `Expected signature: ${getExpectedSignature(hookType)}`
          });
        }
      }
    },
    
    // Security checks
    CallExpression(path) {
      const callee = path.node.callee;
      
      // Check for eval
      if (callee.type === 'Identifier' && callee.name === 'eval') {
        result.errors.push({
          code: 'SECURITY_EVAL',
          message: 'Use of eval() is not allowed in hooks',
          line: path.node.loc?.start.line,
          severity: 'critical'
        });
        result.securityScore -= 30;
      }
      
      // Check for process.exit
      if (
        callee.type === 'MemberExpression' &&
        callee.object.name === 'process' &&
        callee.property.name === 'exit'
      ) {
        result.errors.push({
          code: 'NO_PROCESS_EXIT',
          message: 'Use return with exit code instead of process.exit()',
          line: path.node.loc?.start.line,
          severity: 'error',
          fix: 'return { block: true, exitCode: 2 }'
        });
      }
      
      // Check for dangerous fs operations
      if (
        callee.type === 'MemberExpression' &&
        callee.object.name === 'fs' &&
        ['rm', 'rmdir', 'unlink'].includes(callee.property.name)
      ) {
        result.warnings.push({
          code: 'DANGEROUS_FS_OP',
          message: `Potentially dangerous operation: fs.${callee.property.name}`,
          line: path.node.loc?.start.line,
          severity: 'warning'
        });
        result.securityScore -= 10;
      }
    },
    
    // Check for infinite loops
    WhileStatement(path) {
      if (path.node.test.type === 'BooleanLiteral' && path.node.test.value === true) {
        result.errors.push({
          code: 'INFINITE_LOOP',
          message: 'Potential infinite loop detected',
          line: path.node.loc?.start.line,
          severity: 'error',
          fix: 'Add a break condition or use a for loop with limits'
        });
      }
    }
  });
  
  if (!hasValidExport) {
    result.errors.push({
      code: 'NO_EXPORT',
      message: 'Hook must export a function',
      severity: 'error',
      fix: 'export async function hookName(params) { ... }'
    });
  }
}
```

### Bash Hook Validation
```typescript
async function validateBashHook(
  content: string,
  result: ValidationResult
): Promise<void> {
  const lines = content.split('\n');
  
  // Check shebang
  if (!lines[0]?.startsWith('#!/')) {
    result.errors.push({
      code: 'MISSING_SHEBANG',
      message: 'Bash hooks must start with shebang (#!/bin/bash)',
      line: 1,
      severity: 'error',
      fix: '#!/bin/bash'
    });
  }
  
  // Check for exit codes
  const exitCodes = new Set<number>();
  lines.forEach((line, index) => {
    const exitMatch = line.match(/exit\s+(\d+)/);
    if (exitMatch) {
      exitCodes.add(parseInt(exitMatch[1]));
      
      // Validate exit codes
      if (![0, 1, 2].includes(parseInt(exitMatch[1]))) {
        result.warnings.push({
          code: 'UNUSUAL_EXIT_CODE',
          message: `Unusual exit code: ${exitMatch[1]}. Use 0 (success), 1 (error), or 2 (block)`,
          line: index + 1,
          severity: 'warning'
        });
      }
    }
    
    // Security checks
    if (line.includes('rm -rf')) {
      result.errors.push({
        code: 'DANGEROUS_COMMAND',
        message: 'Dangerous command detected: rm -rf',
        line: index + 1,
        severity: 'critical'
      });
      result.securityScore -= 50;
    }
    
    if (line.includes('eval')) {
      result.warnings.push({
        code: 'EVAL_IN_BASH',
        message: 'Use of eval in bash can be dangerous',
        line: index + 1,
        severity: 'warning'
      });
      result.securityScore -= 20;
    }
  });
  
  result.metadata.exitCodes = Array.from(exitCodes);
}
```

### Pre-Write Settings Validation Hook
```typescript
// hooks/settings-validator/pre-write-settings.ts
export async function preWriteSettingsHook(
  filePath: string,
  content: string
): Promise<HookResult> {
  // Only validate claude settings files
  if (!filePath.includes('claude') || !filePath.endsWith('settings.json')) {
    return { block: false };
  }
  
  try {
    // Parse settings
    const settings = JSON.parse(content);
    
    // Validate hook configurations
    if (settings.hooks) {
      const validationErrors: string[] = [];
      
      for (const [hookType, hookPaths] of Object.entries(settings.hooks)) {
        if (!Array.isArray(hookPaths)) {
          validationErrors.push(`${hookType}: must be an array of paths`);
          continue;
        }
        
        for (const hookPath of hookPaths) {
          const resolvedPath = path.resolve(path.dirname(filePath), hookPath);
          
          // Check if file exists
          if (!fs.existsSync(resolvedPath)) {
            validationErrors.push(`${hookType}: ${hookPath} does not exist`);
            continue;
          }
          
          // Validate the hook
          const validation = await validateHook(resolvedPath);
          
          if (!validation.valid) {
            validationErrors.push(
              `${hookType}: ${hookPath} validation failed:\n` +
              validation.errors.map(e => `  - ${e.message}`).join('\n')
            );
          }
        }
      }
      
      if (validationErrors.length > 0) {
        return {
          block: true,
          message: `❌ Invalid hook configuration:\n${validationErrors.join('\n')}\n\nRun 'claude-hooks validate' to see detailed errors.`
        };
      }
    }
    
    return { block: false };
    
  } catch (error) {
    return {
      block: true,
      message: `❌ Invalid settings.json: ${error.message}`
    };
  }
}
```

### Auto-Fix Capability
```typescript
export async function autoFixHook(
  hookPath: string,
  validation: ValidationResult
): Promise<boolean> {
  let content = await fs.readFile(hookPath, 'utf8');
  let modified = false;
  
  for (const error of validation.errors) {
    if (error.fix) {
      switch (error.code) {
        case 'MISSING_SHEBANG':
          content = error.fix + '\n' + content;
          modified = true;
          break;
          
        case 'NO_PROCESS_EXIT':
          content = content.replace(
            /process\.exit\((\d+)\)/g,
            'return { block: true, exitCode: $1 }'
          );
          modified = true;
          break;
          
        case 'NO_EXPORT':
          // Add export to main function
          content = content.replace(
            /^(async )?function (\w+)/m,
            'export $1function $2'
          );
          modified = true;
          break;
      }
    }
  }
  
  if (modified) {
    await fs.writeFile(hookPath, content);
    console.log(`✅ Auto-fixed ${validation.errors.length} issues in ${hookPath}`);
  }
  
  return modified;
}
```

### Validation Report
```typescript
export function formatValidationReport(
  results: Map<string, ValidationResult>
): string {
  let report = '# Hook Validation Report\n\n';
  
  let totalErrors = 0;
  let totalWarnings = 0;
  
  for (const [file, result] of results) {
    totalErrors += result.errors.length;
    totalWarnings += result.warnings.length;
    
    report += `## ${file}\n`;
    report += `Status: ${result.valid ? '✅ Valid' : '❌ Invalid'}\n`;
    report += `Security Score: ${result.securityScore}/100\n\n`;
    
    if (result.errors.length > 0) {
      report += '### Errors\n';
      for (const error of result.errors) {
        report += `- **${error.code}**: ${error.message}`;
        if (error.line) report += ` (line ${error.line})`;
        if (error.fix) report += `\n  Fix: \`${error.fix}\``;
        report += '\n';
      }
      report += '\n';
    }
    
    if (result.warnings.length > 0) {
      report += '### Warnings\n';
      for (const warning of result.warnings) {
        report += `- **${warning.code}**: ${warning.message}`;
        if (warning.line) report += ` (line ${warning.line})`;
        report += '\n';
      }
      report += '\n';
    }
    
    if (result.suggestions.length > 0) {
      report += '### Suggestions\n';
      for (const suggestion of result.suggestions) {
        report += `- ${suggestion}\n`;
      }
      report += '\n';
    }
  }
  
  report += `\n## Summary\n`;
  report += `- Total files: ${results.size}\n`;
  report += `- Valid hooks: ${Array.from(results.values()).filter(r => r.valid).length}\n`;
  report += `- Total errors: ${totalErrors}\n`;
  report += `- Total warnings: ${totalWarnings}\n`;
  
  return report;
}
```

## Configuration

```json
{
  "validation": {
    "enabled": true,
    "autoValidateOnSave": true,
    "blockInvalidHooks": true,
    "securityScoreThreshold": 70,
    "allowedLanguages": ["javascript", "typescript", "bash"],
    "customRules": [
      {
        "id": "no-console-log",
        "pattern": "console\\.log",
        "message": "Remove console.log statements",
        "severity": "warning"
      }
    ],
    "performance": {
      "maxExecutionTime": 5000,
      "maxMemoryUsage": "50MB"
    }
  },
  "hooks": {
    "pre-write": ["./hooks/settings-validator/pre-write-settings.js"]
  }
}
```

## Usage Examples

### CLI Validation
```bash
$ claude-hooks validate ./hooks/my-hook.js

Validating ./hooks/my-hook.js...

❌ Invalid

Errors:
- NO_EXPORT: Hook must export a function
  Fix: export async function hookName(params) { ... }
- NO_PROCESS_EXIT: Use return with exit code instead of process.exit() (line 15)
  Fix: return { block: true, exitCode: 2 }

Warnings:
- DANGEROUS_FS_OP: Potentially dangerous operation: fs.rm (line 23)

Security Score: 80/100

Run with --fix to automatically fix 2 issues.
```

### Automatic Settings Protection
```bash
$ # When Claude tries to save invalid hook configuration:

❌ Invalid hook configuration:
pre-write: ./hooks/broken-hook.js validation failed:
  - NO_EXPORT: Hook must export a function
  - SECURITY_EVAL: Use of eval() is not allowed in hooks

Run 'claude-hooks validate' to see detailed errors.
```

## Benefits

1. **Prevents Broken Configurations**: Validates before saving
2. **Security Assurance**: Detects dangerous patterns
3. **Debugging Aid**: Clear error messages with fixes
4. **Quality Enforcement**: Ensures hooks follow best practices
5. **Auto-Fix Capability**: Repairs common issues automatically
6. **Performance Protection**: Prevents infinite loops and timeouts

This validation system ensures all hooks are safe, correct, and Claude-compatible before they can affect the system.