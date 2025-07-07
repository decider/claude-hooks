# Task Completion System

## Overview

A hook system designed to prevent Claude from exiting before completing all planned tasks. This ensures thorough task execution and maintains high code quality by enforcing a structured workflow.

## Problem Statement

Claude sometimes exits prematurely before:
- Running tests
- Fixing type errors
- Completing all subtasks
- Verifying build success

This can leave codebases in incomplete states requiring manual cleanup.

## Solution Strategies

### 1. Enhanced TODO File System
```yaml
# .claude-todo (gitignored)
TASK: Implement user authentication
STATUS: in_progress
CREATED: 2025-01-07T10:00:00
STEPS:
- [ ] Create auth service
- [ ] Add login endpoint  
- [ ] Write tests
- [ ] Run build successfully

# On completion: rename to .claude-todo-20250107-auth-implementation
```

### 2. State Machine Approach
```json
{
  "state": "implementing",
  "transitions": {
    "planning": ["implementing"],
    "implementing": ["testing"],
    "testing": ["reviewing", "implementing"],
    "reviewing": ["complete"]
  },
  "blockers": ["Type errors", "Test failures"]
}
```

### 3. Git-Based Guardian
```bash
# Pre-exit hook
if [[ -n $(git status --porcelain) ]]; then
  echo "❌ Uncommitted changes detected. Complete or stash first."
  exit 2
fi
```

### 4. Progressive Lock System
```bash
echo "LOCK_LEVEL=3" > .claude-lock
# After tests pass: LOCK_LEVEL=2
# After typecheck: LOCK_LEVEL=1
# After review: LOCK_LEVEL=0
```

## Minimal Implementation

The most practical approach uses a simple `.claude-task` file with checkboxes:

### Task File Format
```
TASK: Implement user authentication
TODO:
- [ ] Create auth service
- [ ] Add login endpoint
- [ ] Write tests
- [ ] Build passes
```

### Required Hooks

#### 1. Pre-Write Hook
Forces task planning before any code changes:
```bash
#!/bin/bash
# hooks/pre-write.sh
if [[ ! -f .claude-task ]] && [[ "$1" != ".claude-task" ]]; then
  echo "❌ Create .claude-task file first with your plan"
  exit 2
fi
```

#### 2. Post-Bash Hook
Automatically tracks successful build/test commands:
```bash
#!/bin/bash
# hooks/post-bash.sh
if [[ "$1" == *"npm run build"* ]] && [[ $2 -eq 0 ]]; then
  sed -i '' 's/\[ \] Build passes/\[x\] Build passes/' .claude-task
elif [[ "$1" == *"npm test"* ]] && [[ $2 -eq 0 ]]; then
  sed -i '' 's/\[ \] Write tests/\[x\] Write tests/' .claude-task
fi
```

#### 3. Pre-Exit Hook
Blocks exit if tasks remain incomplete:
```bash
#!/bin/bash
# hooks/pre-exit.sh
if [[ -f .claude-task ]]; then
  incomplete=$(grep -c "\[ \]" .claude-task)
  if [[ $incomplete -gt 0 ]]; then
    echo "❌ Complete $incomplete remaining tasks in .claude-task"
    exit 2
  fi
  # Archive completed task
  mv .claude-task ".claude-task-$(date +%Y%m%d-%H%M%S).done"
fi
```

### TypeScript Implementation

For integration with claude-hooks-cli:

```typescript
// src/commands/hooks/task-completion/pre-write.ts
export async function preWriteHook(filePath: string): Promise<HookResult> {
  if (!fs.existsSync('.claude-task') && filePath !== '.claude-task') {
    return {
      block: true,
      message: '❌ Create .claude-task file first with your plan'
    };
  }
  return { block: false };
}

// src/commands/hooks/task-completion/post-bash.ts
export async function postBashHook(command: string, exitCode: number): Promise<void> {
  if (!fs.existsSync('.claude-task')) return;
  
  const content = fs.readFileSync('.claude-task', 'utf8');
  let updated = content;
  
  if (command.includes('npm run build') && exitCode === 0) {
    updated = updated.replace('[ ] Build passes', '[x] Build passes');
  }
  if (command.includes('npm test') && exitCode === 0) {
    updated = updated.replace('[ ] Write tests', '[x] Write tests');
  }
  
  if (updated !== content) {
    fs.writeFileSync('.claude-task', updated);
  }
}

// src/commands/hooks/task-completion/pre-exit.ts
export async function preExitHook(): Promise<HookResult> {
  if (!fs.existsSync('.claude-task')) {
    return { block: false };
  }
  
  const content = fs.readFileSync('.claude-task', 'utf8');
  const incompleteCount = (content.match(/\[ \]/g) || []).length;
  
  if (incompleteCount > 0) {
    return {
      block: true,
      message: `❌ Complete ${incompleteCount} remaining tasks in .claude-task`
    };
  }
  
  // Archive completed task
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  fs.renameSync('.claude-task', `.claude-task-${timestamp}.done`);
  
  return { block: false };
}
```

## Configuration

Add to `claude/settings.json`:
```json
{
  "hooks": {
    "pre-write": ["./hooks/task-completion/pre-write.js"],
    "post-bash": ["./hooks/task-completion/post-bash.js"],
    "pre-exit": ["./hooks/task-completion/pre-exit.js"]
  }
}
```

Add to `.gitignore`:
```
.claude-task
.claude-task-*.done
```

## Benefits

1. **Enforced Planning**: Can't write code without a plan
2. **Progress Tracking**: Visual checkbox progress
3. **Automatic Updates**: Build/test success auto-tracked
4. **Completion Guarantee**: Can't exit with incomplete tasks
5. **Task History**: Archived completed tasks for reference
6. **Minimal Complexity**: ~15 lines of bash total

## Usage Example

1. Claude starts a task
2. Pre-write hook fires → Forces creation of `.claude-task`
3. Claude creates task file with checkboxes
4. Claude implements features
5. Post-bash hook fires → Auto-checks completed items
6. Claude tries to exit
7. Pre-exit hook fires → Blocks if unchecked items remain
8. Once complete → Archives task file with timestamp

## Advanced Features

### Task Templates
Create templates for common tasks:
```bash
# .claude-templates/feature.task
TASK: [FEATURE_NAME]
TODO:
- [ ] Create component/service
- [ ] Add tests
- [ ] Update documentation
- [ ] Run linter
- [ ] Build passes
- [ ] All tests pass
```

### Multi-Step Validation
Enhanced post-bash hook with more checks:
```bash
case "$1" in
  *"npm run lint"*)
    [[ $2 -eq 0 ]] && update_task "Linting passes"
    ;;
  *"npm run typecheck"*)
    [[ $2 -eq 0 ]] && update_task "Type checking passes"
    ;;
  *"npm run test:coverage"*)
    [[ $2 -eq 0 ]] && update_task "Coverage threshold met"
    ;;
esac
```

### Integration with CI
Ensure tasks align with CI requirements:
```yaml
# .claude-ci-requirements.yml
required_checks:
  - build
  - test
  - lint
  - typecheck
  - coverage: 80%
```

This system provides a lightweight but effective way to ensure Claude completes all necessary tasks before moving on.