---
description: "Opt-in: set up the Discord notifications addon (per-issue threads for full-autopilot)."
---

# setup-discord — Discord notifications addon setup (opt-in)

Sets up the **opt-in** Discord notifications addon: full-autopilot streams each Issue's
progress / escalations to a per-issue Discord thread. Reads `addons/discord/addon.yml`.

**This addon is never enabled automatically.** This command must be run explicitly (or enabled
via the `session-start` opt-in prompt).

## Steps

### Step 1: Confirm intent (explicit opt-in)

Ask the user: `Enable Discord notifications addon? It sends full-autopilot status to a Discord forum channel via webhook. [y/N]`. Default **N**. Proceed only on explicit `y`. On no/blank, stop without changes.

### Step 2: Collect the webhook

Ask for the **forum-channel** webhook URL (required) and an optional mention string
(`<@USERID>`, used on escalation). If the user has no webhook, explain they need a Discord
**forum** channel webhook (a normal text-channel webhook cannot create per-issue threads) and stop.

### Step 3: Deploy the notifier

Copy `${CLAUDE_PLUGIN_ROOT}/addons/discord/scripts/fa-notify-discord.sh` → `.claude/addons/fa-notify-discord.sh`.

### Step 4: Configure the hook

Persist to the project env (e.g. `.claude/settings.local.json` `env`, which is gitignored — never commit the webhook):

```jsonc
{
  "env": {
    "FA_NOTIFY_CMD": "bash .claude/addons/fa-notify-discord.sh",
    "FA_DISCORD_WEBHOOK": "<forum-channel webhook URL>",
    "FA_DISCORD_MENTION": "<@USERID>"
  }
}
```

### Step 5: Summary

```
Discord notifications addon enabled:
- Notifier deployed: .claude/addons/fa-notify-discord.sh
- FA_NOTIFY_CMD wired; webhook configured (gitignored)
- full-autopilot will open one Discord thread per Issue
```

Security note: the webhook is a secret — keep it in the gitignored `.claude/settings.local.json`, never in a committed file.
