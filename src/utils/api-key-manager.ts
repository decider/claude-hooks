import { existsSync, readFileSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

export type ApiKeyType = 'gemini' | 'anthropic';

export interface ApiKeyConfig {
  keyName: string;
  envDir: string;
}

const apiKeyConfigs: Record<ApiKeyType, ApiKeyConfig> = {
  gemini: {
    keyName: 'GEMINI_API_KEY',
    envDir: '.gemini'
  },
  anthropic: {
    keyName: 'ANTHROPIC_API_KEY',
    envDir: '.claude'
  }
};

export function getApiKeyConfig(apiKeyType: ApiKeyType = 'anthropic'): ApiKeyConfig {
  return apiKeyConfigs[apiKeyType];
}

export function hasApiKey(apiKeyType: ApiKeyType = 'anthropic'): boolean {
  const config = getApiKeyConfig(apiKeyType);
  const { keyName, envDir } = config;
  
  // Check environment variable
  if (process.env[keyName]) return true;
  
  // Check home directory .env file
  const homeEnvPath = join(homedir(), envDir, '.env');
  if (checkEnvFile(homeEnvPath, keyName)) return true;
  
  // Check project .env file
  const projectEnvPath = join(process.cwd(), '.env');
  if (checkEnvFile(projectEnvPath, keyName)) return true;
  
  return false;
}

function checkEnvFile(path: string, keyName: string): boolean {
  if (existsSync(path)) {
    try {
      const content = readFileSync(path, 'utf-8');
      return content.includes(`${keyName}=`) && !content.includes(`${keyName}=\n`);
    } catch (e) {
      // Ignore errors
    }
  }
  return false;
}

export async function saveApiKey(apiKey: string, apiKeyType: ApiKeyType = 'anthropic'): Promise<void> {
  const config = getApiKeyConfig(apiKeyType);
  const { keyName, envDir } = config;
  const envPath = join(homedir(), envDir, '.env');
  
  let envContent = '';
  if (existsSync(envPath)) {
    envContent = readFileSync(envPath, 'utf-8');
    // Remove existing key if present
    envContent = envContent.split('\n')
      .filter(line => !line.startsWith(`${keyName}=`))
      .join('\n');
    if (envContent && !envContent.endsWith('\n')) {
      envContent += '\n';
    }
  }
  
  envContent += `${keyName}=${apiKey}\n`;
  
  // Ensure directory exists
  const { mkdirSync, writeFileSync } = await import('fs');
  mkdirSync(join(homedir(), envDir), { recursive: true });
  writeFileSync(envPath, envContent, { mode: 0o600 }); // Secure permissions
}