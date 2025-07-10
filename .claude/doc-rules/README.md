# Documentation Compliance Hook

Automatically checks code changes against your project's documentation standards using Gemini Flash API.

## Quick Setup

1. **Set your Gemini API key** (get one at [Google AI Studio](https://makersuite.google.com/app/apikey)):
   ```bash
   export GEMINI_API_KEY="your-key"
   # Or save to ~/.gemini/.env or project .env
   ```

2. **Create `.claude/doc-rules/config.json`** in your project:
   ```json
   {
     "fileTypes": {
       "*.ts": ["docs/typescript-standards.md"],
       "*.py": ["docs/python-standards.md"]
     },
     "directories": {
       "src/api/": ["docs/api-guidelines.md"],
       "tests/": ["docs/testing-standards.md"]
     },
     "thresholds": {
       "default": 0.8,
       "src/api/*": 0.9
     }
   }
   ```

3. **Add your standards** in `docs/` folder (markdown files)

4. **Enable the hook**: `npx claude-code-hooks-cli manage`

## How It Works

The hook triggers on `stop` command and:
1. Extracts only changed lines from git diffs
2. Matches files to relevant docs based on your config
3. Sends to Gemini Flash for fast analysis (~5s)
4. Shows file-grouped issues with line numbers
5. Blocks if score < threshold

## Example Output

```
❌ Documentation compliance check failed!

lib/commands/manage.js
  10: hasApiKey() missing return type
  28: saveApiKey() missing return type
-----

test-compliance.ts
  4: processData() missing return type, uses 'any' type
  12: createUser() missing error handling
  29: maxRetries constant not UPPER_SNAKE_CASE
-----
```

## Performance

- Only analyzes diffs (not full files)
- ~5 seconds for 10 files
- Minimal token usage
- Can apply multiple docs per file