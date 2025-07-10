# TypeScript Coding Standards

## General Principles
- Use TypeScript strict mode
- Avoid `any` type unless absolutely necessary
- Prefer interfaces over type aliases for object shapes

## Naming Conventions
- Use camelCase for variables and functions
- Use PascalCase for classes and interfaces
- Use UPPER_SNAKE_CASE for constants
- Prefix interfaces with 'I' only when necessary to avoid naming conflicts

## Functions
- Always specify return types explicitly
- Use arrow functions for callbacks and short functions
- Limit function parameters to 3-4 maximum
- Document complex functions with JSDoc comments

## Error Handling
- Always handle errors appropriately
- Use try-catch blocks for async operations
- Provide meaningful error messages
- Never silently swallow errors

## Code Organization
- One class/interface per file when possible
- Group related functionality in modules
- Keep files under 300 lines
- Use barrel exports (index.ts) for clean imports

## Example
```typescript
// Good
interface User {
  id: string;
  name: string;
  email: string;
}

async function fetchUser(userId: string): Promise<User> {
  try {
    const response = await api.get(`/users/${userId}`);
    return response.data;
  } catch (error) {
    throw new Error(`Failed to fetch user ${userId}: ${error.message}`);
  }
}

// Bad
async function fetchUser(id) {
  const response = await api.get(`/users/${id}`);
  return response.data;
}
```