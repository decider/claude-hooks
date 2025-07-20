#!/usr/bin/env python3
"""Install Claude Code hooks into a project."""

import os
import shutil
import json
from pathlib import Path

def copy_hooks(source_dir, target_dir):
    """Copy hook files to target directory."""
    for hook_file in source_dir.glob('*.py'):
        shutil.copy2(hook_file, target_dir / hook_file.name)
        os.chmod(target_dir / hook_file.name, 0o755)

def create_hook_config(command):
    """Create a hook configuration."""
    return [{
        "hooks": [{
            "type": "command",
            "command": command
        }]
    }]

def create_settings():
    """Create settings.json configuration."""
    return {
        "hooks": {
            "Stop": create_hook_config("python3 .claude/hooks/universal-stop.py"),
            "PreToolUse": create_hook_config("python3 .claude/hooks/universal-pre-tool.py"),
            "PostToolUse": create_hook_config("python3 .claude/hooks/universal-post-tool.py")
        }
    }

def update_gitignore():
    """Add Claude local settings to .gitignore."""
    gitignore_path = Path('.gitignore')
    if not gitignore_path.exists():
        return
    
    with open(gitignore_path, 'r') as f:
        content = f.read()
    
    if '.claude/settings.local.json' not in content:
        with open(gitignore_path, 'a') as f:
            f.write('\n# Claude Code local settings\n')
            f.write('.claude/settings.local.json\n')

def print_success_message():
    """Print installation success message."""
    print("✅ Claude Code hooks installed successfully!")
    print("\nThe following hooks are now active:")
    print("  - Code quality validation (function/line length, nesting)")
    print("  - Package age validation (blocks old npm packages)")
    print("  - Task completion notifications (optional)")
    print("\nHooks will run automatically when using Claude Code.")

def main():
    """Install hooks into .claude/settings.json."""
    # Create directories
    claude_dir = Path('.claude')
    claude_dir.mkdir(exist_ok=True)
    
    project_hooks_dir = claude_dir / 'hooks'
    project_hooks_dir.mkdir(exist_ok=True)
    
    # Copy hook files
    source_hooks_dir = Path(__file__).parent / 'hooks'
    copy_hooks(source_hooks_dir, project_hooks_dir)
    
    # Create settings.json
    settings_file = claude_dir / 'settings.json'
    with open(settings_file, 'w') as f:
        json.dump(create_settings(), f, indent=2)
    
    # Update .gitignore
    update_gitignore()
    
    # Print success message
    print_success_message()

if __name__ == '__main__':
    main()