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
| [autopilot-worktree-guard.sh](autopilot-worktree-guard.sh) + [autopilot_worktree_guard.py](autopilot_worktree_guard.py) | PreToolUse | Blocks Edit/Write/MultiEdit/NotebookEdit/Bash writes that escape the autopilot session's worktree (gated by `ATDD_AUTOPILOT_WORKTREE` env var; no-op in normal sessions) |
| [bash-output-normalizer.sh](bash-output-normalizer.sh) | PostToolUse (Bash) | Normalizes Bash tool output: JSON minify + blank line collapse + trailing whitespace removal (timeout=10s: balances normalization benefit vs hook overhead; large outputs complete in <1s on typical hardware) |

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

### autopilot-worktree-guard.sh + autopilot_worktree_guard.py

Enforces the autopilot-session rule that file writes must stay inside the active worktree (see Issue #111):

1. Intercepts Edit, Write, MultiEdit, NotebookEdit, and Bash tool calls via PreToolUse hook
2. Reads `ATDD_AUTOPILOT_WORKTREE` (set by `commands/autopilot.md` Phase 0.9 after `EnterWorktree`) — when unset, the hook is a complete no-op so normal (non-autopilot) sessions are unaffected
3. For Edit/Write/MultiEdit/NotebookEdit: canonicalizes `tool_input.file_path` via `realpath` and blocks when it lands outside the worktree and outside the allow-list
4. For Bash: tokenizes `tool_input.command` with Python `shlex.split` (quoted literals such as `echo "a > b"` and stream merges such as `2>&1` are correctly not misdetected), then blocks when any redirect target (`>`, `>>`, `>|`, `&>`, `&>>`, numbered) or mutating-command target (`cp`, `mv`, `rm`, `mkdir`, `touch`, `install`, `tee`, `ln`) escapes the worktree
5. Bypasses path checks entirely when the first token is `git` or `gh` (repo-meta commands manage their own write scope)
6. **Allow-list:** `/tmp`, `/var/folders`, `/private/var/folders`, `/private/tmp`, `/dev/null`, and `<worktree>/.git`
7. **Block contract:** exits 2 with stderr starting `worktree=<W>\nviolating=<path>` so parallel autopilot sessions can unambiguously triage the offender
8. **Fail-safe design:** any unexpected error (missing `python3`, malformed JSON, unparseable command) returns `{}` + exit 0 — the hook never breaks the tool flow

#### Known Limitations (intentional deferrals — Issue #111)

These shell forms are best-effort and may not be detected. The `/tmp` allow-list and separate Edit/Write/MultiEdit/NotebookEdit coverage mitigate the impact:

- **heredoc body targets** (`cat <<EOF > /etc/x\n...\nEOF`) — the outer `> /etc/x` redirect IS detected; body content is not
- **Nested subshell mutations** (`$(cmd > path)`) — only the outer command is inspected
- **`eval "cmd > path"` / `bash -c "cmd > path"`** — command strings are opaque to shlex
- **`exec >path`** redirects — not detected
- **Interpreter-level file IO** (`python -c "open('/p','w').write(...)"`) — target lives inside a Python string literal, unreachable for shlex
- **`$VAR` expansion** (e.g. `$HOME`) — shlex does not expand shell variables; only literal `~` is expanded by the canonicalizer

Python 3 is required in `$PATH` for JSON parsing and shlex tokenization. Standard on macOS and CI; unavailability falls back to no-op (fail-safe).

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
