# Hooks

Hooks are shell commands that execute automatically in response to Claude Code events. They are defined in `hooks.json` and registered by the plugin system.

## How It Works

`hooks.json` declares event handlers that Claude Code's hook system invokes. Each hook specifies:
- **Event type** — When to fire (e.g., `SessionStart`)
- **Matcher** — Pattern to match against the event context
- **Command** — Shell script to execute

## Plugin Hooks (distributed to all users)

| File | Event | Purpose |
|------|-------|---------|
| [hooks.json](hooks.json) | — | Hook definitions — maps events to shell commands |
| [session-start](session-start) | SessionStart | Checks if workflow-config.yml exists; guides first-time setup |

## Development-Only Hooks (atdd-kit repo only)

These hooks are registered in `.claude/settings.json` (project-level), NOT in `hooks.json` (plugin-level). They only affect atdd-kit developers, not end users.

| File | Event | Purpose |
|------|-------|---------|
| [eval-guard.sh](eval-guard.sh) | PreToolUse (Bash) | Blocks `git push` when SKILL.md changes detected without eval evidence |

### eval-guard.sh

Enforces the rule that skill changes require eval before push:

1. Intercepts all Bash tool calls
2. If the command contains `git push`, checks for SKILL.md changes vs origin/main
3. If changes exist, checks for eval evidence marker (`$XDG_CACHE_HOME/atdd-kit/eval-ran-<branch>`)
4. Blocks push with guidance to run `/atdd-kit:auto-eval` if no evidence found

The marker is created by `/atdd-kit:auto-eval` after eval completes.

## References

- [Claude Code hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
