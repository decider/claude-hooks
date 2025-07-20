// Configuration loading utilities

import * as path from 'path';
import * as fs from 'fs';

export interface HookConfig {
  [key: string]: string[] | { [pattern: string]: string[] };
}

export async function loadHookConfig(): Promise<HookConfig | null> {
  let configPath = path.join(process.cwd(), '.claude', 'hooks', 'config.cjs');
  
  if (!fs.existsSync(configPath)) {
    configPath = path.join(process.cwd(), '.claude', 'hooks', 'config.js');
    if (!fs.existsSync(configPath)) {
      return null;
    }
  }
  
  const configUrl = new URL(`file://${configPath}`).href;
  const config = await import(`${configUrl}?t=${Date.now()}`).then(m => m.default || m);
  
  return config;
}

export function getEventConfig(config: HookConfig, eventType: string): any {
  const configKey = eventType ? eventType.charAt(0).toLowerCase() + eventType.slice(1) : '';
  return config[configKey];
}