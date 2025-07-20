// Hook Input Types

export interface BaseHookInput {
  session_id: string;
  transcript_path: string;
  hook_event_name: string;
}

export interface PreToolUseInput extends BaseHookInput {
  hook_event_name: 'PreToolUse';
  tool_name: string;
  tool_input: {
    command?: string;
    file_path?: string;
    content?: string;
    pattern?: string;
    [key: string]: any;
  };
}

export interface PostToolUseInput extends BaseHookInput {
  hook_event_name: 'PostToolUse';
  tool_name: string;
  tool_input: {
    command?: string;
    file_path?: string;
    content?: string;
    pattern?: string;
    [key: string]: any;
  };
  tool_response: {
    success?: boolean;
    filePath?: string;
    error?: string;
    [key: string]: any;
  };
}

export interface StopInput extends BaseHookInput {
  hook_event_name: 'Stop';
  stop_hook_active: boolean;
}

export interface SubagentStopInput extends BaseHookInput {
  hook_event_name: 'SubagentStop';
  stop_hook_active: boolean;
}

export type HookInput = PreToolUseInput | PostToolUseInput | StopInput | SubagentStopInput;

export interface HookOutput {
  continue?: boolean;
  stopReason?: string;
  decision?: 'approve' | 'block';
  reason?: string;
  suppressOutput?: boolean;
}