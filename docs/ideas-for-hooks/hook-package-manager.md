# Hook Package Manager System

## Overview

A proposed package management system for Claude hooks that would enable discovering, sharing, and importing hooks from various repositories. This would create an ecosystem where developers can share their best Claude automation patterns and quickly adopt proven workflows.

**Note: This is a conceptual proposal. The current claude-hooks implementation uses Python scripts installed via `python3 install-hooks.py`.**

## Problem Statement

Currently, Claude hooks are:
- Isolated to individual repositories
- Not easily discoverable or shareable
- Require manual copying between projects
- Lack versioning and dependency management
- Missing community-driven improvements

## Core Features

### 1. Hook Discovery System
Automatically discovers hooks in repositories:
```python
# Conceptual structure for hook sources
class HookSource:
    def __init__(self, type, location, hooks, metadata):
        self.type = type  # 'built-in', 'local', 'remote', 'registry'
        self.location = location
        self.hooks = hooks
        self.metadata = metadata
```

### 2. Hook Registry
Central catalog of available hooks:
```python
# Conceptual registry structure
class HookRegistry:
    def __init__(self):
        self.version = "1.0.0"
        self.sources = []
        self.installed = []
        self.available = []
        self.featured = []
```

### 3. Import/Export Mechanism
Simple commands for hook management:
```bash
# Conceptual commands (not yet implemented)
# These would be future enhancements to the Python-based system

# Import a specific hook from a repository
python3 claude-hooks-manager.py import user/repo:pre-commit-quality

# Import all hooks from a repository
python3 claude-hooks-manager.py import user/repo

# Export hooks for sharing
python3 claude-hooks-manager.py export my-awesome-hooks

# Search available hooks
python3 claude-hooks-manager.py search "quality"

# List installed hooks
python3 claude-hooks-manager.py list
```

## Implementation

### Hook Package Format
```yaml
# .claude-hooks/package.yml
name: "typescript-quality-hooks"
version: "1.0.0"
author: "username"
description: "TypeScript quality enforcement hooks"
tags: ["typescript", "quality", "testing"]

hooks:
  - name: "strict-typescript"
    type: "pre-write"
    description: "Enforces strict TypeScript rules"
    file: "./hooks/strict-typescript.js"
    config:
      strictLevel: "maximum"
      
  - name: "auto-test-generation"
    type: "post-write"
    description: "Generates tests for new functions"
    file: "./hooks/auto-test-gen.js"
    dependencies:
      - "jest"
      - "@types/jest"
```

### Discovery Patterns
The system looks for hooks in these locations:
```python
# Discovery patterns for Python-based hooks
DISCOVERY_PATTERNS = [
    '.claude-hooks/**/*.py',
    'claude/hooks/**/*.py',
    '.claude/hooks/**/*.py',
    'hooks/claude/**/*.py',
  '.github/claude-hooks/**/*.{js,ts,sh}'
];
```

### CLI Commands Implementation

#### Import Command
```typescript
// src/commands/import.ts
export async function importHook(source: string): Promise<void> {
  const [repo, hookName] = source.split(':');
  
  // Clone or fetch repository
  const tempDir = await cloneRepository(repo);
  
  // Discover available hooks
  const discovered = await discoverHooks(tempDir);
  
  if (hookName) {
    // Import specific hook
    const hook = discovered.find(h => h.name === hookName);
    if (!hook) {
      throw new Error(`Hook '${hookName}' not found in ${repo}`);
    }
    await installHook(hook);
  } else {
    // Show selection menu
    const selected = await selectHooks(discovered);
    for (const hook of selected) {
      await installHook(hook);
    }
  }
  
  // Update registry
  await updateLocalRegistry();
}
```

#### Search Command
```typescript
// src/commands/search.ts
export async function searchHooks(query: string): Promise<void> {
  // Search local registry
  const local = await searchLocalRegistry(query);
  
  // Search remote registry (if enabled)
  const remote = await searchRemoteRegistry(query);
  
  // Display results
  console.log('Local hooks:');
  displayHooks(local);
  
  console.log('\nAvailable from registry:');
  displayHooks(remote);
}
```

#### Auto-Discovery on Visit
```typescript
// src/commands/hooks/auto-discover.ts
export async function autoDiscoverHook(cwd: string): Promise<void> {
  // Check if this repo has hooks
  const patterns = DISCOVERY_PATTERNS.map(p => path.join(cwd, p));
  const hookFiles = await glob(patterns);
  
  if (hookFiles.length > 0) {
    // Parse hook definitions
    const hooks = await parseHookFiles(hookFiles);
    
    // Add to available hooks
    await addToAvailable({
      source: cwd,
      hooks: hooks,
      discoveredAt: new Date()
    });
    
    // Notify user
    console.log(`🎯 Discovered ${hooks.length} hooks in current repository`);
    console.log(`Run 'claude-hooks import .' to install them`);
  }
}
```

### Hook Installation Process
```typescript
async function installHook(hook: HookDefinition): Promise<void> {
  // 1. Check compatibility
  await checkCompatibility(hook);
  
  // 2. Install dependencies
  if (hook.dependencies) {
    await installDependencies(hook.dependencies);
  }
  
  // 3. Copy hook files
  const targetDir = path.join(process.cwd(), 'claude/hooks', hook.name);
  await fs.mkdir(targetDir, { recursive: true });
  await fs.copyFile(hook.file, path.join(targetDir, 'index.js'));
  
  // 4. Update configuration
  await updateHookConfig(hook);
  
  // 5. Run installation script if provided
  if (hook.install) {
    await runInstallScript(hook.install);
  }
  
  console.log(`✅ Installed hook: ${hook.name}`);
}
```

### Remote Registry Integration
```typescript
interface RemoteRegistry {
  url: string;
  apiVersion: string;
  
  search(query: string): Promise<HookPackage[]>;
  getPackage(id: string): Promise<HookPackage>;
  publish(package: HookPackage): Promise<void>;
  getStats(packageId: string): Promise<PackageStats>;
}

// Default registry configuration
const DEFAULT_REGISTRY = {
  url: 'https://claude-hooks.dev/api/v1',
  apiVersion: '1.0.0'
};
```

### Hook Sharing Workflow

#### 1. Creating a Hook Package
```bash
# Initialize hook package
claude-hooks init --package

# Creates structure:
# .claude-hooks/
#   ├── package.yml
#   ├── hooks/
#   │   ├── my-hook.js
#   │   └── my-hook.test.js
#   ├── README.md
#   └── examples/
```

#### 2. Publishing to Registry
```bash
# Publish to registry
claude-hooks publish

# Output:
# 📦 Publishing typescript-quality-hooks@1.0.0
# ✅ Published to registry
# 🔗 https://claude-hooks.dev/packages/typescript-quality-hooks
```

#### 3. Installing from Registry
```bash
# Install from registry
claude-hooks install typescript-quality-hooks

# Install specific version
claude-hooks install typescript-quality-hooks@1.0.0
```

## Configuration

### Local Registry Configuration
```json
{
  "registry": {
    "enabled": true,
    "sources": [
      {
        "type": "local",
        "path": "./claude/hooks"
      },
      {
        "type": "remote",
        "url": "https://claude-hooks.dev/api/v1"
      },
      {
        "type": "git",
        "repos": [
          "organization/standard-hooks",
          "myteam/custom-hooks"
        ]
      }
    ],
    "autoDiscover": true,
    "cacheDuration": "7d"
  }
}
```

### Hook Metadata Standard
```typescript
interface HookMetadata {
  name: string;
  version: string;
  description: string;
  author: string;
  license: string;
  
  // Hook specifics
  type: HookType;
  triggers: string[];
  
  // Requirements
  claudeVersion: string;
  platform: string[];
  
  // Configuration schema
  config?: {
    schema: JSONSchema;
    defaults: Record<string, any>;
  };
  
  // Documentation
  readme: string;
  examples: Example[];
  
  // Stats
  downloads?: number;
  stars?: number;
  lastUpdated?: Date;
}
```

## Example Hook Packages

### 1. TypeScript Strict Mode Package
```yaml
name: "typescript-strict"
hooks:
  - strict-null-checks
  - no-any-enforcement  
  - exhaustive-switch
  - immutable-defaults
```

### 2. Git Workflow Package
```yaml
name: "git-workflow"
hooks:
  - conventional-commits
  - branch-protection
  - auto-pr-description
  - changelog-generation
```

### 3. Testing Enhancement Package
```yaml
name: "test-enhancement"
hooks:
  - auto-test-generation
  - coverage-enforcement
  - snapshot-updates
  - test-file-pairing
```

## Benefits

1. **Hook Ecosystem**: Community-driven hook development
2. **Best Practices Sharing**: Learn from proven patterns
3. **Quick Setup**: Import entire workflows instantly
4. **Version Control**: Track hook versions and updates
5. **Discoverability**: Find hooks for specific needs
6. **Standardization**: Consistent hook format and behavior

## Future Enhancements

### Hook Marketplace UI
```typescript
// Web interface for browsing hooks
interface HookMarketplace {
  browse(): HookPackage[];
  search(query: string): HookPackage[];
  install(packageId: string): void;
  rate(packageId: string, rating: number): void;
  comment(packageId: string, comment: string): void;
}
```

### Hook Composition
```yaml
# Compose multiple hooks into workflows
workflows:
  - name: "full-stack-quality"
    hooks:
      - "typescript-strict:pre-write"
      - "eslint-autofix:post-write"
      - "test-generation:post-write"
      - "visual-regression:pre-commit"
```

### AI-Powered Hook Suggestions
```typescript
// Suggest hooks based on project analysis
async function suggestHooks(projectPath: string): Promise<Suggestion[]> {
  const analysis = await analyzeProject(projectPath);
  
  return {
    language: analysis.primaryLanguage,
    frameworks: analysis.frameworks,
    suggestedHooks: [
      {
        hook: "typescript-strict",
        reason: "TypeScript project without strict mode"
      },
      {
        hook: "react-best-practices",
        reason: "React detected without linting rules"
      }
    ]
  };
}
```

This package manager system transforms Claude hooks from isolated scripts into a thriving ecosystem of shared automation patterns.