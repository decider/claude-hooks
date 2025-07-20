# Hierarchical Hook Configuration

The Claude Hooks system now supports hierarchical configuration, allowing you to customize hook behavior at different directory levels.

## How It Works

1. **Root Configuration**: `.claude/hooks.json` defines default hooks for your entire project
2. **Directory Overrides**: Any directory can have a `.claude-hooks.json` file that overrides or extends the parent configuration
3. **Configuration Inheritance**: Settings cascade from root to specific directories, with more specific configs taking precedence

## Configuration Format

All configuration files use JSON format:

```json
{
  "pre-tool": [
    {
      "id": "unique-hook-id",
      "script": "path/to/hook/script.py",
      "file_patterns": ["*.py", "*.js"],
      "priority": 80,
      "config": {
        "custom_setting": "value"
      }
    }
  ],
  "post-tool": [...],
  "stop": [...]
}
```

## Override Behavior

- **Modify Settings**: Reference a hook by ID to change its configuration
- **Disable Hooks**: Set `"disable": true` to turn off a hook in specific directories
- **Add New Hooks**: Define new hooks that only apply to certain directories

## Example Structure

```
project/
├── .claude/
│   └── hooks.json          # Root configuration
├── backend/
│   └── .claude-hooks.json  # Stricter rules for backend
└── frontend/
    └── .claude-hooks.json  # Different rules for frontend
```

## CLI Tools

- `python3 hooks/list_hooks.py list` - Show all hooks in the project
- `python3 hooks/list_hooks.py explain <file>` - Show effective hooks for a specific file

## Benefits

1. **Flexibility**: Different standards for different parts of your codebase
2. **Transparency**: Always know which hooks apply where
3. **Team-Friendly**: Each team can manage their own directory's rules
4. **No YAML Dependencies**: Uses built-in JSON support