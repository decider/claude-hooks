# Continuous UI Improvement System

## Overview

An autonomous hook system that continuously improves UI design by capturing visual feedback, analyzing against design standards, and iterating until quality thresholds are met. The system prevents Claude from exiting until the UI meets specified design criteria.

## Problem Statement

UI development often involves:
- Inconsistent spacing and alignment
- Poor color contrast
- Typography issues
- Deviation from platform design guidelines
- Manual iteration without visual verification

This system automates the refinement process using visual analysis.

## Core Components

### 1. Visual Capture Loop
Integration with Playwright for automated screenshots:
```typescript
interface VisualCapture {
  screenshot: Buffer;
  timestamp: Date;
  component: string;
  viewport: { width: number; height: number };
}
```

### 2. Design Analysis Engine
Analyzes screenshots against design principles:
```typescript
interface DesignMetrics {
  spacing: { score: number; issues: string[] };
  alignment: { score: number; issues: string[] };
  contrast: { score: number; issues: string[] };
  typography: { score: number; issues: string[] };
  platformCompliance: { score: number; issues: string[] };
  overallScore: number;
}
```

### 3. Improvement Cycle
```
Capture → Analyze → Generate Improvements → Apply → Repeat
```

## Implementation

### Task File Structure
```yaml
# .claude-ui-improvement.yml
task: "Improve dashboard UI"
status: "iterating"
targetScore: 85
currentScore: 72
iterations: 3
maxIterations: 10

components:
  - path: "/dashboard"
    selector: ".main-dashboard"
    score: 68
    issues:
      - "Inconsistent padding between cards"
      - "Header text contrast too low"
      
  - path: "/settings"
    selector: ".settings-panel"
    score: 76
    issues:
      - "Button alignment inconsistent"

designSystem: "apple-hig" # or "material", "custom"
```

### Required Hooks

#### 1. Post-Edit Hook with Visual Capture
```typescript
// hooks/ui-improvement/post-edit.ts
import { chromium } from 'playwright';

export async function postEditHook(filePath: string): Promise<void> {
  // Only trigger for UI files
  if (!isUIFile(filePath)) return;
  
  const browser = await chromium.launch();
  const page = await browser.newPage();
  
  // Capture screenshots of affected components
  const config = await loadUIConfig();
  
  for (const component of config.components) {
    await page.goto(`http://localhost:3000${component.path}`);
    await page.waitForSelector(component.selector);
    
    const screenshot = await page.screenshot({
      fullPage: false,
      clip: await page.locator(component.selector).boundingBox()
    });
    
    // Analyze the screenshot
    const metrics = await analyzeDesign(screenshot, config.designSystem);
    
    // Update scores and issues
    component.score = metrics.overallScore;
    component.issues = metrics.getAllIssues();
  }
  
  await saveUIConfig(config);
  await browser.close();
  
  // If score is below threshold, suggest improvements
  if (config.currentScore < config.targetScore) {
    await generateImprovements(config);
  }
}
```

#### 2. Design Analysis Function
```typescript
// hooks/ui-improvement/analyze-design.ts
export async function analyzeDesign(
  screenshot: Buffer, 
  designSystem: string
): Promise<DesignMetrics> {
  // Use image analysis to detect:
  // 1. Element boundaries and spacing
  // 2. Color values and contrast ratios
  // 3. Font sizes and hierarchy
  // 4. Alignment grids
  
  const analysis = {
    spacing: analyzeSpacing(screenshot),
    alignment: analyzeAlignment(screenshot),
    contrast: analyzeContrast(screenshot),
    typography: analyzeTypography(screenshot),
    platformCompliance: checkPlatformGuidelines(screenshot, designSystem)
  };
  
  // Calculate overall score
  const overallScore = Object.values(analysis)
    .reduce((sum, metric) => sum + metric.score, 0) / 5;
    
  return { ...analysis, overallScore };
}
```

#### 3. Improvement Generator
```typescript
// hooks/ui-improvement/generate-improvements.ts
export async function generateImprovements(config: UIConfig): Promise<void> {
  const improvements = [];
  
  for (const component of config.components) {
    for (const issue of component.issues) {
      const improvement = mapIssueToFix(issue, component);
      improvements.push(improvement);
    }
  }
  
  // Create a task file for improvements
  const improvementTasks = improvements.map(imp => ({
    file: imp.file,
    selector: imp.selector,
    change: imp.cssChange,
    rationale: imp.rationale
  }));
  
  await fs.writeFile('.claude-ui-tasks.json', 
    JSON.stringify(improvementTasks, null, 2)
  );
}

function mapIssueToFix(issue: string, component: Component): Improvement {
  const fixMappings = {
    "Inconsistent padding": {
      cssChange: "padding: 16px;",
      rationale: "Standardize padding to 16px grid"
    },
    "text contrast too low": {
      cssChange: "color: #000000; background-color: #FFFFFF;",
      rationale: "Increase contrast ratio to meet WCAG AA"
    },
    "Button alignment inconsistent": {
      cssChange: "display: flex; align-items: center; gap: 8px;",
      rationale: "Use flexbox for consistent alignment"
    }
  };
  
  // Match issue to fix
  for (const [pattern, fix] of Object.entries(fixMappings)) {
    if (issue.includes(pattern)) {
      return {
        file: component.file,
        selector: component.selector,
        ...fix
      };
    }
  }
}
```

#### 4. Pre-Exit Hook
```typescript
// hooks/ui-improvement/pre-exit.ts
export async function preExitHook(): Promise<HookResult> {
  if (!fs.existsSync('.claude-ui-improvement.yml')) {
    return { block: false };
  }
  
  const config = await loadUIConfig();
  
  // Check if we've reached our target score
  if (config.currentScore < config.targetScore) {
    // Check if we've hit max iterations
    if (config.iterations >= config.maxIterations) {
      // Create PR anyway with current state
      await createPullRequest(
        `UI Improvements - Score: ${config.currentScore}/${config.targetScore}`,
        `Automated UI improvements. Reached iteration limit.`
      );
      return { block: false };
    }
    
    return {
      block: true,
      message: `🎨 UI score: ${config.currentScore}/${config.targetScore}. Continuing improvements...`
    };
  }
  
  // Target reached - create PR
  await createPullRequest(
    `UI Improvements - Score Achieved: ${config.currentScore}`,
    `Automated UI improvements meeting design standards.`
  );
  
  // Archive the improvement session
  await archiveImprovementSession(config);
  
  return { block: false };
}
```

### Platform-Specific Guidelines

#### Apple HIG Compliance
```typescript
const appleHIG = {
  spacing: {
    base: 8,
    allowed: [4, 8, 12, 16, 20, 24, 32, 40, 48]
  },
  typography: {
    sizes: [11, 13, 15, 17, 20, 22, 28, 34],
    lineHeight: 1.2
  },
  colors: {
    minContrast: 7.0,
    systemColors: ['systemBlue', 'systemGray', ...]
  }
};
```

#### Material Design Compliance
```typescript
const materialDesign = {
  spacing: {
    base: 8,
    grid: 4
  },
  elevation: {
    levels: [0, 1, 2, 3, 4, 6, 8, 12, 16, 24]
  },
  typography: {
    scale: [12, 14, 16, 20, 24, 34, 48, 60, 96]
  }
};
```

## Configuration

Add to `claude/settings.json`:
```json
{
  "hooks": {
    "post-edit": ["./hooks/ui-improvement/post-edit.js"],
    "pre-exit": ["./hooks/ui-improvement/pre-exit.js"]
  },
  "uiImprovement": {
    "enabled": true,
    "designSystem": "apple-hig",
    "targetScore": 85,
    "maxIterations": 10,
    "devServerUrl": "http://localhost:3000"
  }
}
```

## Workflow Example

1. **Initial State**: Claude edits a React component
2. **Post-Edit Hook**: 
   - Launches Playwright
   - Captures screenshot
   - Analyzes design metrics
   - Score: 72/100
3. **Improvement Generation**:
   - Identifies spacing issues
   - Generates CSS fixes
   - Creates improvement tasks
4. **Iteration Loop**:
   - Claude applies improvements
   - Hook recaptures and reanalyzes
   - Score: 78/100
5. **Continue Until**:
   - Score >= 85 achieved
   - Or max iterations reached
6. **Completion**:
   - Creates PR with improvements
   - Archives session data
   - Allows exit

## Advanced Features

### Visual Regression Testing
```typescript
interface VisualDiff {
  before: Screenshot;
  after: Screenshot;
  diffPercentage: number;
  improvedAreas: Region[];
  degradedAreas: Region[];
}
```

### Multi-Viewport Testing
```typescript
const viewports = [
  { name: 'mobile', width: 375, height: 812 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1440, height: 900 }
];
```

### Accessibility Integration
```typescript
interface A11yMetrics {
  colorContrast: ContrastReport;
  focusIndicators: boolean;
  keyboardNav: boolean;
  ariaLabels: ComplianceReport;
}
```

## Benefits

1. **Automated Refinement**: No manual iteration needed
2. **Visual Validation**: Actual screenshots, not just code analysis
3. **Design Consistency**: Enforces platform guidelines
4. **Quality Guarantee**: Won't exit until standards met
5. **PR Ready**: Automated PR creation when complete
6. **Learning System**: Improves over time with patterns

## Integration with CI/CD

```yaml
# .github/workflows/ui-quality.yml
name: UI Quality Check
on: [pull_request]

jobs:
  ui-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run UI Analysis
        run: |
          npm run dev &
          npx playwright test ui-quality.spec.ts
      - name: Upload Screenshots
        uses: actions/upload-artifact@v2
        with:
          name: ui-analysis
          path: .claude-ui-improvement/
```

This system ensures UI quality through continuous, automated improvement cycles with visual verification.