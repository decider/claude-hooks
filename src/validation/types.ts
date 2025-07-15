export interface ValidationError {
  path: string;
  message: string;
  severity: 'error' | 'warning';
  suggestion?: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
  warnings: ValidationError[];
  fixable: number;
  hookCount?: number;
}

export interface HookGroupValidation {
  matcher?: string;
  pattern?: string;
  hooks: Array<{
    type: string;
    command: string;
  }>;
}

export interface HookSettingsValidation {
  _comment?: string;
  hooks: {
    [event: string]: HookGroupValidation[];
  };
  logging?: {
    enabled?: boolean;
    level?: string;
    path?: string;
    maxSize?: string;
    retention?: string;
  };
}

export const VALID_EVENTS = ['PreToolUse', 'PostToolUse', 'Stop', 'PreWrite', 'PostWrite'] as const;
export type ValidEvent = typeof VALID_EVENTS[number];

export const VALID_TOOLS = [
  'Bash',
  'Write',
  'Edit',
  'MultiEdit',
  'TodoWrite',
  'Read',
  'Grep',
  'Glob',
  'LS',
  'NotebookRead',
  'NotebookEdit',
  'WebFetch',
  'TodoRead',
  'WebSearch',
  'Task',
  'exit_plan_mode',
  '*'
] as const;

export const VALID_LOG_LEVELS = ['debug', 'info', 'warn', 'error'] as const;