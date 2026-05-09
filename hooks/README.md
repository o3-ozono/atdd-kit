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
| [session-start](session-start) | SessionStart | Checks if `.claude/config.yml` (or legacy `workflow-config.yml`) exists; guides first-time setup |
| [main-branch-guard.sh](main-branch-guard.sh) | PreToolUse | Blocks Edit/Write/MultiEdit/NotebookEdit on `main`/`master` branches |
| [bash-output-normalizer.sh](bash-output-normalizer.sh) | PostToolUse (Bash) | Normalizes Bash tool output: JSON minify + blank line collapse + trailing whitespace removal (timeout=10s: balances normalization benefit vs hook overhead; large outputs complete in <1s on typical hardware) |

### main-branch-guard.sh + main_branch_guard.py

Enforces the Issue-driven workflow rule that direct edits on `main`/`master` are not allowed for repository-managed files:

1. Intercepts Edit, Write, MultiEdit, and NotebookEdit tool calls via PreToolUse hook
2. Reads the current git branch with `git branch --show-current`
3. If the branch is not `main` or `master` (case-sensitive exact match), passes through immediately with `{}`
4. On `main`/`master`, delegates to `main_branch_guard.py` which:
   - Parses `tool_input.file_path` (or `tool_input.notebook_path` for NotebookEdit) from the hook JSON
   - Canonicalizes the path via `~` expansion + `os.path.realpath`
   - Checks against an allow-list: `/tmp`, `/private/tmp`, `/var/folders`, `/private/var/folders`, `/dev/null`, `~/.claude/`, `~/.config/`
   - Allow-list match → `{}` exit 0 (edit permitted)
   - No match → `permissionDecision: "deny"` JSON exit 0
5. Deny message instructs users to create a feature branch and use the Issue-driven workflow (no skill names)
6. All unexpected conditions (non-git directory, detached HEAD, git unavailable, python3 unavailable, malformed JSON) pass through safely with `{}`

**Fail-safe design:** Any error condition returns `{}` + exit 0. The hook never blocks edits due to unexpected failures — only explicit `main`/`master` branch matches with non-allow-list paths trigger a deny.

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

## References

- [Claude Code hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
