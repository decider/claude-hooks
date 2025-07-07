## Development Guidelines

- Use TypeScript (.ts) over JavaScript (.js)
- Source files are in `src/` directory
- Compiled output goes to `lib/` directory
- Run `npm run build` to compile TypeScript
- Run `npm run dev` for watch mode during development

## Project Structure

- `src/commands/` - TypeScript command implementations
- `lib/commands/` - Compiled JavaScript (auto-generated)
- `bin/claude-hooks.js` - CLI entry point
- `hooks/` - Legacy shell script hooks (still supported)
- `claude/` - Project-local configuration directory
- `config/` - Example configuration files

## NPM Package

This project is distributed as `claude-code-hooks-cli` NPM package:
- Install: `npm install -D claude-code-hooks-cli`
- Initialize: `npx claude-code-hooks-cli init`
- Commands: `init`, `list`, `manage`, `exec`

## Configuration

- Preferred location: `claude/settings.json` (project-local)
- Legacy location: `.claude/settings.json` (still supported)
- Personal settings: `claude/settings.local.json`
- Global settings: `~/.claude/settings.json`

## Commands
## Commands
- `npm run build` - tsc
- `npm run dev` - tsc --watch
- `npm run typecheck` - tsc --noEmit
- `npm run prepublishOnly` - npm run build
- `npm run test` - echo "No tests configured" && exit 0
- `npm run lint` - echo "No linting configured" && exit 0
- `npm run build` - tsc
- `npm run dev` - tsc --watch
- `npm run typecheck` - tsc --noEmit
- `npm run prepublishOnly` - npm run build
- `npm run test` - echo "No tests configured" && exit 0
- `npm run lint` - echo "No linting configured" && exit 0


## Dependencies
## Dependencies
- chalk@^5.3.0
- commander@^11.0.0
- inquirer@^9.2.15
- chalk@^5.3.0
- commander@^11.0.0
- inquirer@^9.2.15


## Architecture Notes

- Updated on 2025-07-07
- Simplified hook system with focus on essential validation
- Improved error handling and exit codes
- Added common validation library for shared functionality## Architecture Notes

- Updated on 2025-07-07
- Simplified hook system with focus on essential validation
- Improved error handling and exit codes
- Added common validation library for shared functionality