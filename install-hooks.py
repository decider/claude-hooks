#!/usr/bin/env python3
"""Install Claude Code hooks into a project."""

import json
from pathlib import Path


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
            "Stop": create_hook_config("python3 hooks/universal-stop.py"),
            "PreToolUse": create_hook_config("python3 hooks/universal-pre-tool.py"),
            "PostToolUse": create_hook_config("python3 hooks/universal-post-tool.py")
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

def create_quality_validator_config():
    """Create code quality validator configuration."""
    return {
        "max_function_length": 50,
        "max_line_length": 120,
        "max_nesting_depth": 4
    }

def create_package_age_config():
    """Create package age check configuration."""
    return {
        "max_age_years": 2,
        "block_deprecated": True
    }

def create_pre_tool_hooks():
    """Create pre-tool hook configurations."""
    return [
        {
            "id": "code-quality-validator",
            "script": "hooks/portable-quality-validator.py",
            "file_patterns": ["*.py", "*.js", "*.jsx", "*.ts", "*.tsx"],
            "priority": 80,
            "config": create_quality_validator_config()
        },
        {
            "id": "package-age-check",
            "script": "hooks/check-package-age.py",
            "file_patterns": ["package.json", "requirements.txt", "Cargo.toml"],
            "priority": 90,
            "config": create_package_age_config()
        }
    ]

def create_post_tool_hooks():
    """Create post-tool hook configurations."""
    return [
        {
            "id": "post-edit-validator",
            "script": "hooks/post-tool-hook.py",
            "file_patterns": ["*.py", "*.js", "*.jsx", "*.ts", "*.tsx"],
            "priority": 50
        }
    ]

def create_stop_hooks():
    """Create stop hook configurations."""
    return [
        {
            "id": "quality-summary",
            "script": "hooks/stop-hook.py",
            "priority": 100
        },
        {
            "id": "task-notification",
            "script": "hooks/task-completion-notify.py",
            "priority": 50,
            "config": {"enabled": False}
        }
    ]

def create_default_hooks_json():
    """Create the default hooks.json configuration."""
    return {
        "version": 1,
        "pre-tool": create_pre_tool_hooks(),
        "post-tool": create_post_tool_hooks(),
        "stop": create_stop_hooks()
    }

def print_success_message():
    """Print installation success message."""
    print("✅ Claude Code hooks installed successfully!")
    print("\nThe following hooks are now active:")
    print("  - Code quality validation (function/line length, nesting)")
    print("  - Package age validation (blocks old npm packages)")
    print("  - Task completion notifications (optional)")
    print("\nHooks will run automatically when using Claude Code.")
    print("\nYou can now:")
    print("  - List all hooks: python3 hooks/list_hooks.py list")
    print("  - Explain hooks for a file: python3 hooks/list_hooks.py explain <file>")
    print("  - Customize hooks by editing .claude/hooks.json")
    print("  - Add directory-specific overrides with .claude-hooks.json files")

def main():
    """Install hooks into .claude/settings.json."""
    # Create directories
    claude_dir = Path('.claude')
    claude_dir.mkdir(exist_ok=True)
    
    # Create settings.json
    settings_file = claude_dir / 'settings.json'
    with open(settings_file, 'w') as f:
        json.dump(create_settings(), f, indent=2)
    
    # Create hooks.json if it doesn't exist
    hooks_json = claude_dir / 'hooks.json'
    if not hooks_json.exists():
        with open(hooks_json, 'w') as f:
            json.dump(create_default_hooks_json(), f, indent=2)
    
    # Update .gitignore
    update_gitignore()
    
    # Print success message
    print_success_message()

if __name__ == '__main__':
    main()