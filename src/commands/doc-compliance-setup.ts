import { existsSync, mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';
import chalk from 'chalk';
import { docTemplates } from './doc-templates.js';

export interface DocComplianceConfig {
  fileTypes: Record<string, string[]>;
  directories: Record<string, string[]>;
  thresholds: Record<string, number | string>;
}

export function createDefaultDocComplianceConfig(): DocComplianceConfig {
  return {
    fileTypes: {
      "*.ts": ["docs/typescript-standards.md"],
      "*.tsx": ["docs/typescript-standards.md", "docs/react-standards.md"],
      "*.js": ["docs/javascript-standards.md"],
      "*.jsx": ["docs/javascript-standards.md", "docs/react-standards.md"],
      "*.py": ["docs/python-standards.md"],
      "*.java": ["docs/java-standards.md"],
      "*.go": ["docs/go-standards.md"],
      "*.rs": ["docs/rust-standards.md"],
      "*.rb": ["docs/ruby-standards.md"],
      "*.php": ["docs/php-standards.md"],
      "*.c": ["docs/c-standards.md"],
      "*.cpp": ["docs/cpp-standards.md"],
      "*.swift": ["docs/swift-standards.md"],
      "*.kt": ["docs/kotlin-standards.md"],
      "*.sol": ["docs/solidity-standards.md", "docs/security-standards.md"],
      // "// Add more file types as needed": ""
    },
    directories: {
      "src/api/": ["docs/api-design.md"],
      "src/components/": ["docs/component-guidelines.md"],
      "src/utils/": ["docs/utility-standards.md"],
      "src/services/": ["docs/service-patterns.md"],
      "src/models/": ["docs/data-model-standards.md"],
      "tests/": ["docs/testing-standards.md"],
      "scripts/": ["docs/script-guidelines.md"],
      // "// Add more directories as needed": ""
    },
    thresholds: {
      "default": 0.8,
      // "// Higher thresholds for critical code": "",
      "*.sol": 0.95,
      "*.rs": 0.9,
      "src/api/*": 0.9,
      "src/security/*": 0.95,
      // "// Lower thresholds for less critical code": "",
      "tests/*": 0.7,
      "scripts/*": 0.7,
      "*.md": 0.6
    }
  };
}

export function createSampleDocumentation(docsPath: string): void {
  if (!existsSync(docsPath)) {
    mkdirSync(docsPath, { recursive: true });
  }
  
  // Create TypeScript standards
  if (docTemplates.typescript) {
    writeFileSync(join(docsPath, 'typescript-standards.md'), docTemplates.typescript);
    console.log(chalk.green(`✨ Created docs/typescript-standards.md`));
  }
  
  // Create JavaScript standards  
  if (docTemplates.javascript) {
    writeFileSync(join(docsPath, 'javascript-standards.md'), docTemplates.javascript);
    console.log(chalk.green(`✨ Created docs/javascript-standards.md`));
  }
  
  // Create React standards
  if (docTemplates.react) {
    writeFileSync(join(docsPath, 'react-standards.md'), docTemplates.react);
    console.log(chalk.green(`✨ Created docs/react-standards.md`));
  }
}

export function setupDocCompliance(projectRoot: string = process.cwd()): void {
  const configPath = join(projectRoot, '.claude', 'doc-rules', 'config.json');
  const docsPath = join(projectRoot, 'docs');
  
  // Create default config if it doesn't exist
  if (!existsSync(configPath)) {
    const configDir = join(projectRoot, '.claude', 'doc-rules');
    if (!existsSync(configDir)) {
      mkdirSync(configDir, { recursive: true });
    }
    
    const defaultConfig = createDefaultDocComplianceConfig();
    writeFileSync(configPath, JSON.stringify(defaultConfig, null, 2));
    console.log(chalk.green(`\n✨ Created default config at ${configPath}`));
    
    // Create sample documentation
    createSampleDocumentation(docsPath);
    
    console.log(chalk.yellow('\n📝 Next steps:'));
    console.log(chalk.gray('1. Get a Gemini API key from https://makersuite.google.com/app/apikey'));
    console.log(chalk.gray('2. Set GEMINI_API_KEY in your environment'));
    console.log(chalk.gray('3. Create your documentation standards in the docs/ folder'));
    console.log(chalk.gray('4. Customize .claude/doc-rules/config.json for your project\n'));
  }
}