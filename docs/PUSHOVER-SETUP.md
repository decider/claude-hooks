# Pushover Notifications Setup Guide

Enable reliable notifications that bypass Do Not Disturb mode using Pushover.

## Prerequisites

1. **Get Pushover** ($5 one-time license per platform)
   - Visit: https://pushover.net/
   - Download the app for your device(s)
   - Create an account

2. **Create an Application**
   - Go to: https://pushover.net/apps/build
   - Name: "Claude Code" (or your preferred name)
   - Type: Application
   - Icon: Optional (you can use any icon you like)
   - Click "Create Application"
   - Copy your **API Token/Key**

3. **Get Your User Key**
   - Find it on your Pushover dashboard: https://pushover.net/dashboard
   - It's the long string under "Your User Key"

## Configuration Methods

Choose ONE of the following methods to configure Pushover:

### Method 1: Project-Specific (Recommended)
Perfect for different settings per project:

```bash
# In your project root
echo "PUSHOVER_USER_KEY=your-user-key-here" >> .env
echo "PUSHOVER_APP_TOKEN=your-app-token-here" >> .env

# Make sure .env is in .gitignore!
echo ".env" >> .gitignore
```

### Method 2: Claude-Specific Config
For project-specific Claude settings:

```bash
# Create Claude config directory if needed
mkdir -p .claude

# Add Pushover config
echo "PUSHOVER_USER_KEY=your-user-key-here" >> .claude/pushover.env
echo "PUSHOVER_APP_TOKEN=your-app-token-here" >> .claude/pushover.env

# Add to .gitignore
echo ".claude/pushover.env" >> .gitignore
```

### Method 3: Global Configuration
For all projects on your machine:

```bash
# Add to your global Claude config
echo "PUSHOVER_USER_KEY=your-user-key-here" >> ~/.claude/pushover.env
echo "PUSHOVER_APP_TOKEN=your-app-token-here" >> ~/.claude/pushover.env
```

### Method 4: Environment Variables
For temporary or CI/CD use:

```bash
# Add to ~/.zshrc or ~/.bashrc
export PUSHOVER_USER_KEY="your-user-key-here"
export PUSHOVER_APP_TOKEN="your-app-token-here"

# Reload your shell
source ~/.zshrc  # or source ~/.bashrc
```

## Notification Priority Levels

The hook uses smart priority levels:

- **Normal (0)**: Regular file edits, commits
- **High (1)**: Build completions, test results, git push
- **Emergency (2)**: Deploy operations (bypasses DND, repeats until acknowledged)

## Testing Your Setup

1. **Enable debug logging**:
   ```bash
   export CLAUDE_HOOK_LOG=/tmp/claude-notifications.log
   ```

2. **Test with a simple file edit**:
   ```bash
   echo "test" > test-notification.txt
   ```

3. **Check the log**:
   ```bash
   tail -f /tmp/claude-notifications.log
   ```

## Troubleshooting

### Not receiving notifications?

1. **Check your configuration**:
   ```bash
   # This should show your keys
   echo $PUSHOVER_USER_KEY
   echo $PUSHOVER_APP_TOKEN
   ```

2. **Test Pushover directly**:
   ```bash
   curl -s \
     --form-string "token=$PUSHOVER_APP_TOKEN" \
     --form-string "user=$PUSHOVER_USER_KEY" \
     --form-string "message=Test from Claude Code" \
     https://api.pushover.net/1/messages.json
   ```

3. **Verify hook is configured**:
   ```bash
   cat ~/.claude/settings.json | jq '.hooks.PostToolUse'
   ```

### Common Issues

- **"invalid token"**: Double-check your app token (not user key)
- **"invalid user"**: Double-check your user key (not app token)
- **No notifications on macOS**: Ensure Terminal has notification permissions
- **Silent notifications**: Check your Pushover app notification settings

## Security Best Practices

1. **Never commit API keys**: Always add `.env` files to `.gitignore`
2. **Use separate tokens**: Create different apps for different projects/teams
3. **Rotate keys regularly**: Regenerate tokens if they might be compromised
4. **Limit key scope**: Use project-specific configs when possible

## Advanced Usage

### Custom Notification Sounds
Pushover supports various notification sounds. Modify the hook to use different sounds:
- `pushover` - Pushover (default)
- `bike` - Bike
- `bugle` - Bugle
- `cashregister` - Cash Register
- `classical` - Classical
- `cosmic` - Cosmic
- And many more!

### Team Notifications
Create a Pushover group and use the group key instead of your personal user key to notify your entire team.

### Integration with CI/CD
Set `PUSHOVER_USER_KEY` and `PUSHOVER_APP_TOKEN` as secrets in your CI/CD environment to get notifications about automated builds and deployments.