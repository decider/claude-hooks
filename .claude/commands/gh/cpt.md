# GitHub Commit Push Track (CPT) Workflow

Execute the complete GitHub workflow: commit → push → create PR → monitor CI/CD → fix failures → repeat until all checks pass.

## Workflow Steps

You MUST follow this complete workflow in order:

### 1. Pre-commit Validation
- Run `git status` and `git diff --cached` to review staged changes
- If no changes are staged, inform the user and exit
- Verify the current branch is not `main` or `master`

### 2. Create Commit
- Analyze the staged changes to understand what was modified
- Create a descriptive commit message following conventional commit format
- Use this exact format for the commit:
```bash
git commit -m "$(cat <<'EOF'
[conventional commit message here]

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### 3. Push and Create PR
- Push the current branch to remote: `git push -u origin HEAD`
- Create a PR using `gh pr create` with a descriptive title and body
- The PR body should include:
  - ## Summary (1-3 bullet points)
  - ## Test plan (checklist for testing)
  - Footer: `🤖 Generated with [Claude Code](https://claude.ai/code)`
- Capture and display the PR URL

### 4. Monitor GitHub Actions (Critical Loop)
Execute this monitoring loop until ALL checks pass:

```bash
# Check PR status every 30 seconds
while true; do
    echo "🔍 Checking GitHub Actions status..."
    gh pr checks --watch
    
    # Get detailed status
    CHECKS_STATUS=$(gh pr checks --json state,conclusion,name,detailsUrl)
    
    # Parse for any failures
    FAILED_CHECKS=$(echo "$CHECKS_STATUS" | jq -r '.[] | select(.conclusion == "failure" or .conclusion == "cancelled") | .name')
    
    if [ -z "$FAILED_CHECKS" ]; then
        echo "✅ All checks passed! Workflow complete."
        break
    fi
    
    echo "❌ Found failing checks: $FAILED_CHECKS"
    echo "📋 Analyzing failure logs..."
    
    # Get failure details
    echo "$CHECKS_STATUS" | jq -r '.[] | select(.conclusion == "failure" or .conclusion == "cancelled") | "Check: " + .name + "\nDetails: " + .detailsUrl'
    
    # Break the loop here - let Claude analyze and fix
    break
done
```

### 5. Fix Failures (If Any)
When checks fail:
- Analyze the failure logs from the GitHub Actions
- Identify the root cause of each failure
- Fix the issues in the codebase
- Create a new commit with the fixes
- Push the fixes: `git push`
- Return to step 4 (monitoring loop)

### 6. Completion
- Display final success message with PR URL
- Show summary of commits made during the process
- Confirm all GitHub Actions are passing

## Important Notes

- **Never force push** - always use regular `git push`
- **Wait for checks** - Allow adequate time for GitHub Actions to complete
- **Fix incrementally** - Address one failure at a time when possible
- **Maintain git history** - Each fix should be a separate commit
- **Monitor continuously** - Check status every 30 seconds during the monitoring phase

## Usage
Simply run `/gh:cpt` in Claude Code after staging your changes. The command will handle the complete workflow automatically.

## Prerequisites
- Changes must be staged (`git add`)
- Current branch must not be main/master
- `gh` CLI must be authenticated
- GitHub repository must have Actions enabled