export const docTemplates = {
  typescript: `# TypeScript Coding Standards

## Type Safety
- Always specify return types for functions
- Avoid using \`any\` type - use \`unknown\` or specific types instead
- Use interfaces for object shapes
- Enable strict mode in tsconfig.json

## Naming Conventions
- Use camelCase for variables and functions
- Use PascalCase for classes, interfaces, and type aliases
- Use UPPER_SNAKE_CASE for constants
- Use descriptive names that clearly indicate purpose

## Error Handling
- All async functions must have proper error handling
- Use try-catch blocks for operations that might fail
- Provide meaningful error messages
- Log errors appropriately

## Code Organization
- Keep files under 300 lines
- One class/interface per file for major components
- Group related functionality together
- Use barrel exports (index.ts) for clean imports

## Example Violations
\`\`\`typescript
// ❌ Bad
function processData(data: any) {
  return data.map(item => item.value);
}

// ✅ Good  
function processData(data: DataItem[]): number[] {
  return data.map(item => item.value);
}
\`\`\`
`,

  javascript: `# JavaScript Coding Standards

## Variable Declaration
- Use \`const\` by default, \`let\` when reassignment is needed
- Never use \`var\`
- Declare variables at the top of their scope

## Functions
- Use arrow functions for callbacks
- Use function declarations for named functions
- Keep functions small and focused (< 20 lines)

## Error Handling
- Always handle promise rejections
- Use try-catch for async/await
- Provide meaningful error messages

## Modern JavaScript
- Use ES6+ features appropriately
- Prefer array methods over loops
- Use destructuring for cleaner code`,

  python: `# Python Coding Standards

## Style Guide
- Follow PEP 8
- Use 4 spaces for indentation
- Maximum line length of 79 characters

## Naming Conventions
- snake_case for functions and variables
- PascalCase for classes
- UPPER_CASE for constants

## Type Hints
- Use type hints for function parameters and returns
- Use typing module for complex types
- Document expected types in docstrings

## Error Handling
- Use specific exception types
- Always clean up resources with context managers
- Log errors appropriately`,

  react: `# React Component Standards

## Component Structure
- Use functional components with hooks
- One component per file
- Keep components under 200 lines

## Props and State
- Define PropTypes or TypeScript interfaces
- Use descriptive prop names
- Minimize state, lift when necessary

## Hooks
- Follow Rules of Hooks
- Extract custom hooks for reusable logic
- Use useMemo/useCallback appropriately

## Performance
- Avoid inline function definitions in render
- Use React.memo for expensive components
- Lazy load large components`
};

export function getDocTemplate(language: string): string | undefined {
  return docTemplates[language as keyof typeof docTemplates];
}