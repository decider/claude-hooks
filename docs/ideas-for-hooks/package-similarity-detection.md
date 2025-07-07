# Package Similarity Detection Hook

## Overview

A hook system that prevents installation of duplicate or similar packages by analyzing existing dependencies and suggesting alternatives. This helps maintain a clean dependency tree, reduces bundle size, and prevents functionality overlap.

## Problem Statement

Common package management issues:
- Installing multiple packages that do the same thing (e.g., `lodash` + `underscore`)
- Adding packages when similar functionality already exists
- Bloated `package.json` with redundant dependencies
- Conflicting package versions or implementations
- Team members unaware of existing solutions

## Core Components

### 1. Package Analysis Engine
```typescript
interface PackageAnalysis {
  name: string;
  category: PackageCategory;
  functionality: string[];
  keywords: string[];
  dependencies: string[];
  size: number;
  popularity: number;
}

enum PackageCategory {
  UTILITY = "utility",
  UI_COMPONENT = "ui-component", 
  DATE_TIME = "date-time",
  HTTP_CLIENT = "http-client",
  VALIDATION = "validation",
  TESTING = "testing",
  BUNDLER = "bundler",
  CSS_FRAMEWORK = "css-framework"
}
```

### 2. Similarity Detector
```typescript
interface SimilarityMatch {
  existingPackage: string;
  newPackage: string;
  similarityScore: number;
  reason: SimilarityReason;
  recommendation: string;
  confidence: number;
}

enum SimilarityReason {
  SAME_CATEGORY = "same-category",
  OVERLAPPING_FUNCTIONALITY = "overlapping-functionality",
  KEYWORD_MATCH = "keyword-match",
  DEPENDENCY_OVERLAP = "dependency-overlap",
  SIZE_REDUNDANCY = "size-redundancy"
}
```

## Implementation

### Package Installation Hook
```typescript
// hooks/package-similarity/pre-install.ts
export async function preInstallHook(
  command: string,
  packages: string[]
): Promise<HookResult> {
  // Only trigger for package installation commands
  if (!isPackageInstallCommand(command)) {
    return { block: false };
  }
  
  const packageJson = await readPackageJson();
  const existingPackages = [
    ...Object.keys(packageJson.dependencies || {}),
    ...Object.keys(packageJson.devDependencies || {})
  ];
  
  const blockers: string[] = [];
  const warnings: string[] = [];
  
  for (const newPackage of packages) {
    const analysis = await analyzePackageSimilarity(newPackage, existingPackages);
    
    if (analysis.hasBlockingConflict) {
      blockers.push(formatBlockingMessage(analysis));
    } else if (analysis.hasSimilarPackages.length > 0) {
      warnings.push(formatWarningMessage(analysis));
    }
  }
  
  if (blockers.length > 0) {
    return {
      block: true,
      message: `🚫 Package installation blocked:\n\n${blockers.join('\n\n')}`
    };
  }
  
  if (warnings.length > 0) {
    console.log(`⚠️  Package similarity warnings:\n${warnings.join('\n')}`);
  }
  
  return { block: false };
}

function isPackageInstallCommand(command: string): boolean {
  const installPatterns = [
    /npm install/,
    /npm i /,
    /yarn add/,
    /pnpm add/,
    /bun add/
  ];
  
  return installPatterns.some(pattern => pattern.test(command));
}
```

### Similarity Analysis Engine
```typescript
async function analyzePackageSimilarity(
  newPackage: string,
  existingPackages: string[]
): Promise<PackageAnalysisResult> {
  // Get package metadata
  const newPackageInfo = await getPackageInfo(newPackage);
  
  const similarPackages: SimilarityMatch[] = [];
  
  for (const existingPkg of existingPackages) {
    const existingInfo = await getPackageInfo(existingPkg);
    const similarity = calculateSimilarity(newPackageInfo, existingInfo);
    
    if (similarity.score > 0.7) {
      similarPackages.push(similarity);
    }
  }
  
  return {
    newPackage: newPackageInfo,
    hasSimilarPackages: similarPackages,
    hasBlockingConflict: similarPackages.some(s => s.similarityScore > 0.9),
    recommendations: generateRecommendations(similarPackages)
  };
}

function calculateSimilarity(
  pkg1: PackageAnalysis, 
  pkg2: PackageAnalysis
): SimilarityMatch {
  let score = 0;
  const reasons: SimilarityReason[] = [];
  
  // Category match (high weight)
  if (pkg1.category === pkg2.category) {
    score += 0.4;
    reasons.push(SimilarityReason.SAME_CATEGORY);
  }
  
  // Functionality overlap
  const functionalityOverlap = calculateArrayOverlap(
    pkg1.functionality, 
    pkg2.functionality
  );
  score += functionalityOverlap * 0.3;
  if (functionalityOverlap > 0.5) {
    reasons.push(SimilarityReason.OVERLAPPING_FUNCTIONALITY);
  }
  
  // Keyword similarity  
  const keywordOverlap = calculateArrayOverlap(pkg1.keywords, pkg2.keywords);
  score += keywordOverlap * 0.2;
  if (keywordOverlap > 0.4) {
    reasons.push(SimilarityReason.KEYWORD_MATCH);
  }
  
  // Size consideration (if both are large)
  if (pkg1.size > 100000 && pkg2.size > 100000) {
    score += 0.1;
    reasons.push(SimilarityReason.SIZE_REDUNDANCY);
  }
  
  return {
    existingPackage: pkg2.name,
    newPackage: pkg1.name,
    similarityScore: Math.min(score, 1.0),
    reason: reasons[0] || SimilarityReason.KEYWORD_MATCH,
    recommendation: generateRecommendation(pkg1, pkg2, score),
    confidence: calculateConfidence(reasons.length, score)
  };
}
```

### Package Categories and Rules
```typescript
const PACKAGE_CATEGORIES = {
  'lodash': { category: 'utility', functionality: ['array', 'object', 'functional'] },
  'underscore': { category: 'utility', functionality: ['array', 'object', 'functional'] },
  'ramda': { category: 'utility', functionality: ['functional', 'immutable'] },
  
  'moment': { category: 'date-time', functionality: ['parsing', 'formatting', 'manipulation'] },
  'dayjs': { category: 'date-time', functionality: ['parsing', 'formatting', 'lightweight'] },
  'date-fns': { category: 'date-time', functionality: ['functional', 'modular', 'immutable'] },
  
  'axios': { category: 'http-client', functionality: ['requests', 'interceptors', 'browser'] },
  'fetch': { category: 'http-client', functionality: ['requests', 'native', 'lightweight'] },
  'superagent': { category: 'http-client', functionality: ['requests', 'plugins'] },
  
  'joi': { category: 'validation', functionality: ['schema', 'object', 'validation'] },
  'yup': { category: 'validation', functionality: ['schema', 'validation', 'async'] },
  'zod': { category: 'validation', functionality: ['typescript', 'schema', 'type-safe'] },
  
  'react': { category: 'ui-framework', functionality: ['components', 'virtual-dom', 'jsx'] },
  'vue': { category: 'ui-framework', functionality: ['components', 'reactive', 'templates'] },
  'angular': { category: 'ui-framework', functionality: ['components', 'typescript', 'cli'] }
};

const BLOCKING_RULES = [
  {
    pattern: ['lodash', 'underscore'],
    message: 'Both lodash and underscore provide similar utility functions',
    recommendation: 'Choose one utility library. lodash is more popular and actively maintained.'
  },
  {
    pattern: ['moment', 'dayjs', 'date-fns'],
    message: 'Multiple date manipulation libraries detected',
    recommendation: 'Use date-fns for modern projects (tree-shakeable) or dayjs for moment.js compatibility.'
  },
  {
    pattern: ['axios', 'node-fetch', 'isomorphic-fetch'],
    message: 'Multiple HTTP client libraries detected',
    recommendation: 'axios for feature-rich needs, native fetch for modern browsers/Node 18+.'
  }
];
```

### Message Formatting
```typescript
function formatBlockingMessage(analysis: PackageAnalysisResult): string {
  const similar = analysis.hasSimilarPackages[0];
  
  return `Package: ${analysis.newPackage.name}
❌ Similar package already installed: ${similar.existingPackage}
📊 Similarity: ${(similar.similarityScore * 100).toFixed(0)}%
🎯 Reason: ${similar.reason}

💡 Recommendation: ${similar.recommendation}

To proceed anyway: npm install ${analysis.newPackage.name} --force`;
}

function formatWarningMessage(analysis: PackageAnalysisResult): string {
  const similar = analysis.hasSimilarPackages[0];
  
  return `⚠️  ${analysis.newPackage.name} is similar to ${similar.existingPackage} (${(similar.similarityScore * 100).toFixed(0)}% match)
   Consider using existing package or consolidating functionality.`;
}
```

### Smart Recommendations
```typescript
function generateRecommendations(matches: SimilarityMatch[]): string[] {
  const recommendations: string[] = [];
  
  for (const match of matches) {
    if (match.similarityScore > 0.9) {
      recommendations.push(`Use existing ${match.existingPackage} instead`);
    } else if (match.similarityScore > 0.7) {
      recommendations.push(`Consider extending ${match.existingPackage} functionality`);
    } else {
      recommendations.push(`Evaluate if ${match.existingPackage} meets your needs`);
    }
  }
  
  return recommendations;
}
```

## Configuration

```json
{
  "packageSimilarity": {
    "enabled": true,
    "blockingThreshold": 0.9,
    "warningThreshold": 0.7,
    "customRules": [
      {
        "packages": ["custom-utility", "lodash"],
        "action": "block",
        "message": "Use our internal custom-utility package"
      }
    ],
    "allowedOverrides": [
      {
        "pattern": "testing-*",
        "reason": "Multiple testing libraries are acceptable"
      }
    ],
    "excludePatterns": [
      "@types/*",
      "eslint-*"
    ]
  }
}
```

## Example Scenarios

### Scenario 1: Blocking Duplicate Utility
```bash
$ npm install underscore

🚫 Package installation blocked:

Package: underscore
❌ Similar package already installed: lodash
📊 Similarity: 95%
🎯 Reason: same-category

💡 Recommendation: Both provide utility functions. lodash is more popular and actively maintained.

To proceed anyway: npm install underscore --force
```

### Scenario 2: Warning for Similar Package
```bash
$ npm install dayjs

⚠️  dayjs is similar to moment (78% match)
   Consider using existing package or consolidating functionality.

Installing dayjs...
```

### Scenario 3: Smart Alternative Suggestion
```bash
$ npm install request

🚫 Package installation blocked:

Package: request
❌ Similar package already installed: axios
📊 Similarity: 85%
🎯 Reason: overlapping-functionality

💡 Recommendation: axios provides modern Promise-based HTTP client. request is deprecated.

Alternative: Use axios for HTTP requests or native fetch for lightweight needs.
```

## Benefits

1. **Dependency Hygiene**: Prevents bloated package.json files
2. **Bundle Size Optimization**: Reduces redundant code in bundles
3. **Team Consistency**: Enforces consistent package choices across team
4. **Learning Tool**: Educates developers about existing solutions
5. **Maintenance Reduction**: Fewer packages to update and maintain
6. **Conflict Prevention**: Avoids version conflicts between similar packages

## Advanced Features

### Package Ecosystem Analysis
```typescript
interface EcosystemAnalysis {
  framework: 'react' | 'vue' | 'angular' | 'node';
  recommendedPackages: Record<string, string[]>;
  discouragedCombinations: string[][];
}
```

### Smart Bundling Insights
```typescript
interface BundleImpact {
  currentSize: number;
  projectedSize: number;
  redundantCode: string[];
  treeshakingOpportunities: string[];
}
```

This hook ensures teams maintain clean, efficient dependency trees while learning about existing solutions.