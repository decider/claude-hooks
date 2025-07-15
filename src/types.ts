export interface HookConfig {
  event: string;
  matcher?: string;
  pattern?: string;
  description: string;
  requiresApiKey?: boolean;
  apiKeyType?: string;
}

export interface HookConfigs {
  [key: string]: HookConfig;
}

export interface SettingsLocation {
  path: string;
  dir: string;
  file: string;
  display: string;
  description: string;
  level: string;
}

export interface HookSettings {
  _comment?: string;
  hooks: {
    [event: string]: Array<{
      matcher?: string;
      pattern?: string;
      hooks: Array<{
        type: string;
        command: string;
      }>;
    }>;
  };
}

export interface HookInfo {
  event: string;
  groupIndex: number;
  hookIndex: number;
  name: string;
  matcher?: string;
  pattern?: string;
  command: string;
  description: string;
  stats: HookStats;
}

export interface HookStats {
  count: number;
  lastCall: string | null;
}

export interface HookStatDisplay {
  name: string;
  count: number;
  lastCall: string | null;
  relativeTime: string;
}

export interface HookTemplate extends HookConfig {
  command?: string;
  requiresApiKey?: boolean;
  apiKeyType?: string;
}

export interface HookTemplates {
  [key: string]: HookTemplate;
}

export type HookSource = 'built-in' | 'project' | 'custom';

export interface DiscoveredHook extends HookConfig {
  name: string;
  source: HookSource;
  command?: string;
  requiresApiKey?: boolean;
  apiKeyType?: string;
}