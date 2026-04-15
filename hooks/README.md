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
| [main-branch-guard.sh](main-branch-guard.sh) | PreToolUse | Blocks Edit/Write/MultiEdit/NotebookEdit on `main`/`master` branches |
| [bash-output-normalizer.sh](bash-output-normalizer.sh) | PostToolUse (Bash) | Normalizes Bash tool output: JSON minify + blank line collapse + trailing whitespace removal |

### main-branch-guard.sh

Enforces the Issue-driven workflow rule that direct edits on `main`/`master` are not allowed:

1. Intercepts Edit, Write, MultiEdit, and NotebookEdit tool calls via PreToolUse hook
2. Reads the current git branch with `git branch --show-current`
3. If the branch is exactly `main` or `master` (case-sensitive), denies the tool call with a `permissionDecision: "deny"` response
4. The deny message includes guidance to use `/atdd-kit:issue` and `/atdd-kit:autopilot`
5. All unexpected conditions (non-git directory, detached HEAD, git unavailable) pass through safely with `{}`

**Fail-safe design:** Any error condition returns `{}` + exit 0. The hook never blocks edits due to unexpected failures — only explicit `main`/`master` branch matches trigger a deny.

#### Emergency Recovery (if the hook misbehaves)

If the hook incorrectly blocks edits (e.g., after a bug is introduced), use one of these methods to restore access:

**Option 1: Switch to a feature branch (recommended)**
```bash
git checkout -b fix/recover-hook-issue
# Edit main-branch-guard.sh on this branch, then open a PR
```

**Option 2: Temporarily remove the hook entry from hooks.json**

In the atdd-kit repository, on a feature branch, edit `hooks/hooks.json` and remove the PreToolUse entry temporarily. After recovery, restore it via PR.

**Option 3: Override via Claude Code settings (project-level)**

In your project's `.claude/settings.json`, add a hook that returns `{}` for the same matcher before the plugin hook runs.

## Development-Only Hooks (atdd-kit repo only)

These hooks are registered in `.claude/settings.json` (project-level), NOT in `hooks.json` (plugin-level). They only affect atdd-kit developers, not end users.

| File | Event | Purpose |
|------|-------|---------|
| [eval-guard.sh](eval-guard.sh) | PreToolUse (Bash) | Blocks `git push` when SKILL.md changes detected without eval evidence |

### eval-guard.sh

Enforces the rule that skill changes require eval before push:

1. Intercepts all Bash tool calls
2. If the command is a `git push` (not in arguments), checks for SKILL.md changes on this branch vs merge-base with origin/main
3. If changes exist, checks for eval evidence marker (`$XDG_CACHE_HOME/atdd-kit/eval-ran-<branch>`)
4. Blocks push with guidance to run `/atdd-kit:auto-eval` if no evidence found

The marker is created by `/atdd-kit:auto-eval` after eval completes.

## References

- [Claude Code hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
