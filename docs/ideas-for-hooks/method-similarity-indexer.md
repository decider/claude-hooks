# Method Similarity Indexer Hook

## Overview

An intelligent code analysis system that maintains a searchable index of all methods across the repository, detects similar functionality when new methods are written, and prevents code duplication by suggesting existing implementations.

## Problem Statement

Common code duplication issues:
- Developers unknowingly implement methods that already exist
- Similar utility functions scattered across different files
- Inconsistent naming for similar functionality
- Code review overhead to catch duplicates
- Growing technical debt from redundant implementations
- Team members unaware of existing helper functions

## Core Components

### 1. Method Indexer
```typescript
interface MethodIndex {
  signature: string;
  name: string;
  filePath: string;
  lineNumber: number;
  parameters: Parameter[];
  returnType: string;
  functionality: FunctionalitySignature;
  language: string;
  lastUpdated: Date;
}

interface FunctionalitySignature {
  purpose: string;
  semanticTokens: string[];
  inputTypes: string[];
  outputType: string;
  sideEffects: boolean;
  complexity: number;
  domain: string;
}
```

### 2. Similarity Engine
```typescript
interface SimilarityMatch {
  existingMethod: MethodIndex;
  newMethod: MethodAnalysis;
  similarityScore: number;
  matchReasons: MatchReason[];
  recommendation: string;
  confidence: number;
}

enum MatchReason {
  SEMANTIC_SIMILARITY = "semantic-similarity",
  PARAMETER_MATCH = "parameter-match", 
  RETURN_TYPE_MATCH = "return-type-match",
  NAME_SIMILARITY = "name-similarity",
  FUNCTIONALITY_OVERLAP = "functionality-overlap",
  INPUT_OUTPUT_PATTERN = "input-output-pattern"
}
```

## Implementation

### Repository Indexing System
```typescript
// hooks/method-indexer/repo-indexer.ts
export async function buildMethodIndex(repoPath: string): Promise<MethodIndex[]> {
  const index: MethodIndex[] = [];
  
  // Find all code files
  const codeFiles = await glob([
    '**/*.{js,ts,jsx,tsx,py,java,go,rs,rb,php}',
    '!**/node_modules/**',
    '!**/dist/**',
    '!**/build/**'
  ], { cwd: repoPath });
  
  for (const file of codeFiles) {
    const filePath = path.join(repoPath, file);
    const content = await fs.readFile(filePath, 'utf8');
    const language = detectLanguage(file);
    
    // Parse methods based on language
    const methods = await parseMethodsFromFile(content, language, filePath);
    
    // Analyze each method's functionality
    for (const method of methods) {
      const functionality = await analyzeFunctionality(method, content);
      
      index.push({
        ...method,
        functionality,
        language,
        lastUpdated: new Date()
      });
    }
  }
  
  // Save index for quick lookups
  await saveMethodIndex(index);
  
  return index;
}
```

### Language-Specific Parsers
```typescript
// hooks/method-indexer/parsers/typescript-parser.ts
export async function parseTypeScriptMethods(
  content: string, 
  filePath: string
): Promise<MethodIndex[]> {
  const ast = parse(content, {
    sourceType: 'module',
    plugins: ['typescript', 'jsx']
  });
  
  const methods: MethodIndex[] = [];
  
  traverse(ast, {
    FunctionDeclaration(path) {
      const method = extractMethodInfo(path.node, filePath);
      methods.push(method);
    },
    
    MethodDefinition(path) {
      const method = extractMethodInfo(path.node, filePath);
      methods.push(method);
    },
    
    ArrowFunctionExpression(path) {
      // Only if assigned to variable
      if (path.parent.type === 'VariableDeclarator') {
        const method = extractMethodInfo(path.node, filePath, path.parent.id.name);
        methods.push(method);
      }
    }
  });
  
  return methods;
}

function extractMethodInfo(node: any, filePath: string, name?: string): MethodIndex {
  return {
    signature: generateSignature(node),
    name: name || node.id?.name || 'anonymous',
    filePath,
    lineNumber: node.loc.start.line,
    parameters: extractParameters(node.params),
    returnType: extractReturnType(node.returnType),
    functionality: {}, // Will be analyzed separately
    language: 'typescript',
    lastUpdated: new Date()
  };
}
```

### Functionality Analysis Engine
```typescript
// hooks/method-indexer/functionality-analyzer.ts
export async function analyzeFunctionality(
  method: MethodIndex,
  sourceCode: string
): Promise<FunctionalitySignature> {
  // Extract method body
  const methodBody = extractMethodBody(sourceCode, method.lineNumber);
  
  // Semantic analysis
  const semanticTokens = await extractSemanticTokens(methodBody);
  const purpose = await inferPurpose(method.name, methodBody, semanticTokens);
  
  // Analyze patterns
  const inputTypes = method.parameters.map(p => p.type);
  const outputType = method.returnType;
  const sideEffects = detectSideEffects(methodBody);
  const complexity = calculateComplexity(methodBody);
  const domain = classifyDomain(semanticTokens, method.filePath);
  
  return {
    purpose,
    semanticTokens,
    inputTypes,
    outputType,
    sideEffects,
    complexity,
    domain
  };
}

function extractSemanticTokens(methodBody: string): string[] {
  // Extract meaningful words and operations
  const tokens = [];
  
  // Extract variable names, method calls, keywords
  const variableNames = methodBody.match(/\b[a-zA-Z_][a-zA-Z0-9_]*\b/g) || [];
  const methodCalls = methodBody.match(/\w+\(/g)?.map(m => m.slice(0, -1)) || [];
  const keywords = ['sort', 'filter', 'map', 'reduce', 'find', 'validate', 'format', 'parse'];
  
  tokens.push(...variableNames, ...methodCalls);
  tokens.push(...keywords.filter(k => methodBody.includes(k)));
  
  // Remove common words and duplicates
  return [...new Set(tokens)]
    .filter(token => !['const', 'let', 'var', 'return', 'if', 'else'].includes(token))
    .slice(0, 20); // Top 20 semantic tokens
}

function inferPurpose(name: string, body: string, tokens: string[]): string {
  // Use method name and semantic analysis to infer purpose
  const purposePatterns = {
    'format': ['format', 'transform', 'convert'],
    'validate': ['validate', 'check', 'verify', 'test'],
    'sort': ['sort', 'order', 'arrange'],
    'filter': ['filter', 'select', 'where'],
    'parse': ['parse', 'extract', 'decode'],
    'calculate': ['calculate', 'compute', 'sum', 'count'],
    'fetch': ['fetch', 'get', 'retrieve', 'load'],
    'save': ['save', 'store', 'persist', 'write']
  };
  
  for (const [purpose, patterns] of Object.entries(purposePatterns)) {
    const nameMatch = patterns.some(p => name.toLowerCase().includes(p));
    const tokenMatch = patterns.some(p => tokens.some(t => t.toLowerCase().includes(p)));
    
    if (nameMatch || tokenMatch) {
      return purpose;
    }
  }
  
  return 'utility';
}
```

### Pre-Write Similarity Detection Hook
```typescript
// hooks/method-indexer/pre-write-similarity.ts
export async function preWriteSimilarityHook(
  filePath: string,
  content: string
): Promise<HookResult> {
  // Only check code files
  if (!isCodeFile(filePath)) {
    return { block: false };
  }
  
  // Parse new methods being written
  const language = detectLanguage(filePath);
  const newMethods = await parseMethodsFromContent(content, language);
  
  if (newMethods.length === 0) {
    return { block: false };
  }
  
  // Load existing method index
  const methodIndex = await loadMethodIndex();
  
  const conflicts: SimilarityMatch[] = [];
  
  for (const newMethod of newMethods) {
    // Analyze functionality of new method
    const functionality = await analyzeFunctionality(newMethod, content);
    const newMethodWithFunc = { ...newMethod, functionality };
    
    // Find similar existing methods
    const similarities = await findSimilarMethods(newMethodWithFunc, methodIndex);
    
    // Filter high-confidence matches
    const highConfidenceMatches = similarities.filter(s => s.similarityScore > 0.8);
    
    conflicts.push(...highConfidenceMatches);
  }
  
  if (conflicts.length > 0) {
    return {
      block: true,
      message: formatSimilarityMessage(conflicts)
    };
  }
  
  return { block: false };
}
```

### Similarity Calculation
```typescript
async function findSimilarMethods(
  newMethod: MethodAnalysis,
  index: MethodIndex[]
): Promise<SimilarityMatch[]> {
  const matches: SimilarityMatch[] = [];
  
  for (const existingMethod of index) {
    const similarity = calculateMethodSimilarity(newMethod, existingMethod);
    
    if (similarity.score > 0.6) {
      matches.push({
        existingMethod,
        newMethod,
        similarityScore: similarity.score,
        matchReasons: similarity.reasons,
        recommendation: generateRecommendation(similarity),
        confidence: similarity.confidence
      });
    }
  }
  
  return matches.sort((a, b) => b.similarityScore - a.similarityScore);
}

function calculateMethodSimilarity(
  method1: MethodAnalysis,
  method2: MethodIndex
): { score: number; reasons: MatchReason[]; confidence: number } {
  let score = 0;
  const reasons: MatchReason[] = [];
  
  // Name similarity (using edit distance)
  const nameScore = calculateNameSimilarity(method1.name, method2.name);
  if (nameScore > 0.7) {
    score += nameScore * 0.3;
    reasons.push(MatchReason.NAME_SIMILARITY);
  }
  
  // Parameter similarity
  const paramScore = calculateParameterSimilarity(
    method1.parameters, 
    method2.parameters
  );
  if (paramScore > 0.8) {
    score += paramScore * 0.25;
    reasons.push(MatchReason.PARAMETER_MATCH);
  }
  
  // Return type match
  if (method1.returnType === method2.returnType) {
    score += 0.15;
    reasons.push(MatchReason.RETURN_TYPE_MATCH);
  }
  
  // Semantic token overlap
  const semanticScore = calculateSemanticSimilarity(
    method1.functionality.semanticTokens,
    method2.functionality.semanticTokens
  );
  if (semanticScore > 0.5) {
    score += semanticScore * 0.2;
    reasons.push(MatchReason.SEMANTIC_SIMILARITY);
  }
  
  // Purpose match
  if (method1.functionality.purpose === method2.functionality.purpose) {
    score += 0.1;
    reasons.push(MatchReason.FUNCTIONALITY_OVERLAP);
  }
  
  return {
    score: Math.min(score, 1.0),
    reasons,
    confidence: reasons.length / 5 // More reasons = higher confidence
  };
}
```

### Smart Recommendations
```typescript
function formatSimilarityMessage(conflicts: SimilarityMatch[]): string {
  let message = '🔍 Similar methods detected:\n\n';
  
  for (const conflict of conflicts) {
    const existing = conflict.existingMethod;
    const similarity = (conflict.similarityScore * 100).toFixed(0);
    
    message += `❌ Method "${conflict.newMethod.name}" is ${similarity}% similar to:\n`;
    message += `   📍 ${existing.name}() in ${existing.filePath}:${existing.lineNumber}\n`;
    message += `   🎯 Reason: ${conflict.matchReasons.join(', ')}\n`;
    message += `   💡 ${conflict.recommendation}\n\n`;
  }
  
  message += '🚀 Consider using existing methods or refactoring for better code reuse.\n';
  message += 'To proceed anyway, rename your method or add --force flag.';
  
  return message;
}

function generateRecommendation(similarity: SimilarityMatch): string {
  const score = similarity.similarityScore;
  const existing = similarity.existingMethod;
  
  if (score > 0.95) {
    return `Nearly identical to existing method. Use ${existing.name}() instead.`;
  } else if (score > 0.85) {
    return `Very similar functionality. Consider extending ${existing.name}() or creating shared utility.`;
  } else if (score > 0.75) {
    return `Similar pattern detected. Review ${existing.name}() for potential reuse.`;
  } else {
    return `Some overlap with ${existing.name}(). Consider if consolidation makes sense.`;
  }
}
```

### Index Maintenance
```typescript
// hooks/method-indexer/index-updater.ts
export async function updateMethodIndex(
  filePath: string,
  changeType: 'added' | 'modified' | 'deleted'
): Promise<void> {
  const index = await loadMethodIndex();
  
  switch (changeType) {
    case 'added':
    case 'modified':
      // Re-parse the file and update index
      const language = detectLanguage(filePath);
      const content = await fs.readFile(filePath, 'utf8');
      const methods = await parseMethodsFromFile(content, language, filePath);
      
      // Remove old entries for this file
      const filteredIndex = index.filter(m => m.filePath !== filePath);
      
      // Add new entries
      for (const method of methods) {
        const functionality = await analyzeFunctionality(method, content);
        filteredIndex.push({ ...method, functionality });
      }
      
      await saveMethodIndex(filteredIndex);
      break;
      
    case 'deleted':
      // Remove all methods from deleted file
      const updatedIndex = index.filter(m => m.filePath !== filePath);
      await saveMethodIndex(updatedIndex);
      break;
  }
}
```

## Configuration

```json
{
  "methodSimilarity": {
    "enabled": true,
    "blockingThreshold": 0.8,
    "warningThreshold": 0.6,
    "languages": ["typescript", "javascript", "python", "java"],
    "excludePaths": [
      "**/*.test.ts",
      "**/*.spec.ts", 
      "**/migrations/**"
    ],
    "indexUpdateFrequency": "on-save",
    "semanticAnalysis": {
      "enabled": true,
      "minTokenOverlap": 0.5
    },
    "customDomains": [
      {
        "name": "authentication",
        "keywords": ["auth", "login", "token", "session"]
      },
      {
        "name": "data-processing", 
        "keywords": ["transform", "process", "convert", "parse"]
      }
    ]
  }
}
```

## Example Scenarios

### Scenario 1: Identical Functionality
```typescript
// Existing method in utils/string.ts:25
function formatUserName(firstName: string, lastName: string): string {
  return `${firstName} ${lastName}`.trim();
}

// New method being written:
function getUserDisplayName(first: string, last: string): string {
  return `${first} ${last}`.trim();
}
```

**Hook Response:**
```
🔍 Similar methods detected:

❌ Method "getUserDisplayName" is 94% similar to:
   📍 formatUserName() in utils/string.ts:25
   🎯 Reason: semantic-similarity, parameter-match, functionality-overlap
   💡 Nearly identical to existing method. Use formatUserName() instead.

🚀 Consider using existing methods or refactoring for better code reuse.
```

### Scenario 2: Similar Pattern
```typescript
// Existing: utils/validation.ts:15
function validateEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// New method being written:
function isValidEmailAddress(emailAddr: string): boolean {
  return /\S+@\S+\.\S+/.test(emailAddr);
}
```

**Hook Response:**
```
🔍 Similar methods detected:

❌ Method "isValidEmailAddress" is 87% similar to:
   📍 validateEmail() in utils/validation.ts:15
   🎯 Reason: name-similarity, parameter-match, functionality-overlap
   💡 Very similar functionality. Consider extending validateEmail() or creating shared utility.
```

## Benefits

1. **Code Deduplication**: Prevents writing duplicate methods
2. **Knowledge Sharing**: Helps developers discover existing utilities
3. **Consistency**: Encourages using established patterns
4. **Maintenance**: Reduces code to maintain and test
5. **Code Review**: Catches duplicates before they reach production
6. **Learning Tool**: Educates team about existing codebase

## Advanced Features

### Semantic Search
```typescript
// CLI tool for searching methods by functionality
claude-hooks search-methods "format date to string"
// Returns: formatDate(), dateToString(), convertDateFormat()
```

### Refactoring Suggestions
```typescript
interface RefactoringSuggestion {
  duplicateMethods: MethodIndex[];
  suggestedUnification: {
    newName: string;
    parameters: Parameter[];
    implementation: string;
  };
  filesAffected: string[];
}
```

This system creates a living index of your codebase's methods, preventing duplication and promoting code reuse across the entire repository.