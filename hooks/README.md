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
| [main-branch-guard.sh](main-branch-guard.sh) | PreToolUse | Blocks Edit/Write/MultiEdit/NotebookEdit of project-repo files whose worktree is on `main`/`master` |
| [branch-lease-guard.sh](branch-lease-guard.sh) | PreToolUse (Bash) | Blocks write-back operations (git push / gh pr edit / merge / ready) on branches with open Draft PRs held by another session |
| [bash-output-normalizer.sh](bash-output-normalizer.sh) | PostToolUse (Bash) | Normalizes Bash tool output: JSON minify + blank line collapse + trailing whitespace removal (timeout=10s: balances normalization benefit vs hook overhead; large outputs complete in <1s on typical hardware) |

### main-branch-guard.sh + main_branch_guard.py

Enforces the Issue-driven workflow rule that direct edits on `main`/`master` are not allowed — scoped to the **project repository** and decided by the **target file's worktree branch**, not the session cwd branch (#251):

1. Intercepts Edit, Write, MultiEdit, and NotebookEdit tool calls via PreToolUse hook
2. `main-branch-guard.sh` only reads the hook input, verifies `git`/`python3` are available (otherwise fail-safe `{}`), and delegates to `main_branch_guard.py` — all decision logic lives on the Python side
3. `main_branch_guard.py` parses `tool_input.file_path` (or `tool_input.notebook_path` for NotebookEdit), canonicalizes it via `~` expansion + `os.path.realpath` (new files resolve through the nearest existing ancestor directory), then decides in three stages:
   - **(a)** The project repository is the repo of the hook `cwd`, identified by `git rev-parse --git-common-dir` (worktrees share the common dir). If it cannot be resolved → fail-safe `{}`
   - **(b)** The target file's common dir cannot be resolved, or differs from the cwd's → the file is **outside the project repository** → `{}` (e.g. dotfiles repos, other projects)
   - **(c)** Common dirs match but the **target-side worktree** branch is not `main`/`master` (case-sensitive exact match; detached HEAD counts as non-main) → `{}` (e.g. feature worktrees while cwd is on main)
   - **(d)** Target worktree is on `main`/`master` → allow-list check: `/tmp`, `/private/tmp`, `/var/folders`, `/private/var/folders`, `/dev/null`, `~/.claude/`, `~/.config/`. Match → `{}`; no match → `permissionDecision: "deny"` JSON exit 0
4. Deny message instructs users to create a feature branch and use the Issue-driven workflow (no skill names)
5. All unexpected conditions (non-git directory, git unavailable, python3 unavailable, malformed JSON) pass through safely with `{}`

**Fail-safe design:** Any error condition returns `{}` + exit 0. The hook never blocks edits due to unexpected failures — only project-repo files whose worktree is on `main`/`master` and that miss the allow-list trigger a deny.

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

### branch-lease-guard.sh

Prevents write-back operations (git push, gh pr edit/merge/ready) on branches that have an open Draft PR held by another active session (#316):

1. Intercepts Bash tool calls via PreToolUse hook
2. Identifies write-back operations: `git push` (all forms including `--force*`), `gh pr edit`, `gh pr merge`, `gh pr ready`. Non-write-back ops (checkout, switch, local rebase, etc.) pass through immediately.
3. Resolves the target branch from the command: explicit argument in `git push`, or PR branch via `gh pr view`, falling back to `git branch --show-current`.
4. `main`/`master` always passes through.
5. Checks the shared **lease store** (`BRANCH_LEASE_DIR`, default `/tmp/claude-branch-leases/`) for another session's fresh lease on the target branch.
6. If another session holds a fresh lease **and** `gh pr list` confirms an open Draft PR on that branch → `permissionDecision: "deny"` JSON + exit 0 (hard block).
7. If no blocking condition: allows, and acquires a lease for the current session (`session_id` from hook input).

**Lease store:** One JSON file per branch (URL-encoded filename): `{session_id, timestamp}`. Shared across sessions on the same machine via filesystem.

**TTL:** `BRANCH_LEASE_TTL_LOCAL` (default 7200s / 2h) for local; `BRANCH_LEASE_TTL_CI` (default 2400s / 40min, when `GITHUB_ACTIONS` is set). Stale leases are deleted at access time (orphan cleanup — no daemon needed).

**Override escape hatch:** `ATDD_BRANCH_LEASE_FORCE=1` unconditionally allows — use to break out of a stuck lease situation.

**Fail-safe:** Any unexpected condition (jq/git unavailable, malformed stdin, gh failure) returns `{}` + exit 0 (allow). The hook never blocks due to unexpected failures.

#### Emergency Recovery (if the hook misbehaves)

**Option 1: Remove the stale lease manually**
```bash
ls /tmp/claude-branch-leases/          # or your BRANCH_LEASE_DIR
rm /tmp/claude-branch-leases/<branch>.json
```

**Option 2: Override for the current command**
```bash
ATDD_BRANCH_LEASE_FORCE=1 git push origin <branch>
```

**Option 3: Remove the hook entry from hooks.json (feature branch)**

In the atdd-kit repository, on a feature branch, edit `hooks/hooks.json` and remove the Bash PreToolUse entry for `branch-lease-guard.sh` temporarily.

## References

- [Claude Code hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
