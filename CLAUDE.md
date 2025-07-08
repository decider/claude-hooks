# Claude Hooks CLI

A command-line tool for managing Claude Code hooks - validation and quality checks that run automatically within Claude.

## Overview
This project provides a CLI tool to easily manage hooks for Claude Code (claude.ai/code). Hooks allow you to run validation, linting, type checking, and other quality checks automatically before certain actions in Claude.

## Available Hooks

### Code Quality
- **typescript-check**: TypeScript type checking before git commits
- **lint-check**: Code linting (ESLint, etc.) before git commits  
- **test-check**: Run test suite before various operations
- **code-quality-validator**: Enforces clean code standards (function length, nesting, etc.) after file edits

### Package Management
- **check-package-age**: Prevents installation of outdated npm/yarn packages

### Notifications
- **task-completion-notify**: System notifications for completed tasks

## Commands
- `npm run build` - Compile TypeScript to JavaScript
- `npm run dev` - Watch mode for development
- `npm run typecheck` - Type check without emitting
- `npm run prepublishOnly` - Build before publishing
- `npm run test` - Run tests (placeholder)
- `npm run lint` - Run linter (placeholder)

## Dependencies
- chalk@^5.3.0 - Terminal styling
- commander@^11.0.0 - CLI framework
- inquirer@^9.2.15 - Interactive prompts

## Architecture Notes
- Written in TypeScript
- Modular design with separate commands
- Hook validation system
- Interactive UI for hook management
- Supports multiple settings file locations

---
_Manually maintained project documentation_