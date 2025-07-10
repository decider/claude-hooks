# Pushover Setup for Claude Notifications

Get notifications when Claude finishes tasks.

## Quick Setup

1. **Get Pushover** ($5 one-time)
   - Download: https://pushover.net/
   - Create account
   - Get your User Key from dashboard

2. **Create App**
   - Visit: https://pushover.net/apps/build
   - Name it "Claude Code"
   - Copy the API Token

3. **Configure** (add to `.env` in project root)
   ```bash
   PUSHOVER_USER_KEY=your-user-key
   PUSHOVER_APP_TOKEN=your-app-token
   ```

4. **Test**
   ```bash
   curl -s \
     --form-string "token=$PUSHOVER_APP_TOKEN" \
     --form-string "user=$PUSHOVER_USER_KEY" \
     --form-string "message=Test" \
     https://api.pushover.net/1/messages.json
   ```

## Alternative Locations
- Global: `~/.claude/pushover.env`
- Project: `.claude/pushover.env`
- Shell: Add to `~/.zshrc`

## Troubleshooting
- **No notifications?** Check Terminal has notification permissions
- **Invalid token?** Token is from app, not user dashboard
- **Invalid user?** User key is from dashboard, not app