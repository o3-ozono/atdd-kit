---
name: session-start
description: "Session start report -- git status, PR/CI, Issue list, recommended tasks. Auto-invoked by other skills."
---

# Session Start Routine

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill entirely.
</SUBAGENT-STOP>

For speed, run independent information-gathering steps **in parallel**. However, Phase 0 must complete **alone** before anything else.

## Phase 0: Update Repository (highest priority, run alone)

1. `git branch --show-current` to check the current branch
2. `git status --short` to check uncommitted changes
3. **On main:** `git pull origin main --ff-only` to update
4. **Not on main:** Run branch auto-return logic (below)
5. **Stale Worktree Cleanup:** `git worktree list --porcelain` to detect orphaned worktrees. If stale worktrees exist (directory missing or inactive), run `git worktree prune` to clean up. Record results for Phase 3 report.
6. `git log --oneline -5` to check recent commits

### Branch Auto-Return Logic

1. `git fetch origin main`
2. `git log --oneline origin/main..HEAD --no-merges` to check unmerged commits
3. 0 commits -> `git checkout main && git pull origin main` (auto-return)
4. 1+ commits -> `gh pr list --head <branch> --state merged` to check for merged PRs
5. Merged PR found -> squash-merged and already integrated -> auto-return to main
6. No merged PR -> report as ongoing work

## Phase 1: Information Gathering (parallel)

### A. GitHub Account Check
- `gh api user --jq .login` to verify the authenticated account

### B. Open PRs and CI
1. `gh pr list --author @me --state open` to list open PRs
2. For open PRs -> `gh pr view <number> --json title,state,reviewDecision,statusCheckRollup,mergeable,mergeStateStatus` for CI results and conflict status

### C. GitHub Issues
- `gh issue list --state open --limit 20` to list open Issues

### D. First-Time Setup (if workflow-config.yml missing)

If `.claude/workflow-config.yml` does not exist, run first-time auto-setup:

1. **Auto-detect platform** from project structure:
   - `*.xcodeproj`, `*.xcworkspace`, or `Package.swift` exists → `ios`
   - `package.json` exists → `web`
   - Neither detected → show: "No platform detected. Run `/atdd-kit:setup-ios` or `/atdd-kit:setup-web` to configure manually."
2. **Confirm** with user — read `${CLAUDE_PLUGIN_ROOT}/addons/<platform>/addon.yml` and show what will be installed:
   ```
   <Platform> project detected. The following will be set up:

   MCP Servers:  <list mcp_servers keys from addon.yml>
   Hooks:        <list matcher patterns from addon.yml hooks>
   Deploy Files: <list dest paths from addon.yml deploy>
   Skills:       <list skills from addon.yml>

   Proceed? [Y/n]
   ```
3. **Process addon**: Execute the addon manifest:
   - **MCP servers**: Merge `mcp_servers` into project `.mcp.json` (create if missing, preserve existing entries)
   - **Deploy files**: Copy each `deploy` entry from `${CLAUDE_PLUGIN_ROOT}/addons/<platform>/<src>` to project `<dest>` (create directories as needed)
   - **Hooks**: Add `hooks.PreToolUse` entries to `.claude/settings.json` (create base settings if missing, preserve existing hooks)
   - **Guidance**: Display the `guidance` text to user
4. **Write** `.claude/workflow-config.yml`:
   ```yaml
   platform: [<detected-platform>]
   ```
5. Continue to Phase 1-E (plugin version check)

### E. Plugin Version Check
- Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-plugin-version.sh "${CLAUDE_PLUGIN_ROOT}" "${HOME}/.claude/plugin-cache"`
- Parse the output:
  - `FIRST_RUN`: First time using the plugin. Show current version in report.
  - `NO_UPDATE`: Version unchanged. No notification needed.
  - `UPDATED`: Version changed. Show old → new version and CHANGELOG diff in report.

### E2. Auto-Sync on Plugin Update (only if UPDATED)

If `check-plugin-version.sh` returned `UPDATED`, synchronize project files from the plugin.

#### Addon-Based File Sync

Read `.claude/workflow-config.yml` to determine `platform` setting. For each platform in the list:

1. Read `${CLAUDE_PLUGIN_ROOT}/addons/<platform>/addon.yml`
2. For each entry in the `deploy` section: copy `${CLAUDE_PLUGIN_ROOT}/addons/<platform>/<src>` to project `<dest>` (overwrite without asking)

#### Always-Sync Files

These files are always synced regardless of platform:

| Plugin Source | Project Destination |
|-------------|-------------------|
| `templates/issue/en/*.yml` (all files) | `.github/ISSUE_TEMPLATE/*.yml` |
| `templates/issue/ja/*.yml` (all files) | `.github/ISSUE_TEMPLATE/*-ja.yml` |
| `templates/pr/en/pull_request_template.md` | `.github/pull_request_template.md` |

Record synced files for the Phase 3 Plugin Sync report.

### F. Recent Activity (24h)

Fetch recently merged PRs and closed Issues (past 24 hours) in parallel:

1. `gh pr list --state merged --search "merged:>=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)" --limit 10 --json number,title,mergedAt`
2. `gh issue list --state closed --json number,title,closedAt --limit 10` and filter to last 24h

If both results are empty, skip the Recent Activity section entirely in the report.

### G. Agent Teams Environment Check

Ensure `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is configured in `.claude/settings.local.json` (per-machine, gitignored).

1. **Read** `.claude/settings.local.json`
   - If file does not exist: create `.claude/` directory if needed (`mkdir -p .claude`), then write:
     ```json
     {
       "env": {
         "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
       }
     }
     ```
     Report: "Agent Teams env var configured in `.claude/settings.local.json`"
   - If file exists but contains invalid JSON: report warning "`.claude/settings.local.json` contains invalid JSON — cannot auto-configure Agent Teams env var. Please fix the file manually." Skip this step (do not block session-start).
   - If file exists and valid JSON:
     - Check if `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` key exists
     - If missing: deep-merge `{"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}}` into existing content, preserving all other keys and all existing `env` entries (e.g., `GH_TOKEN`). Write back.
       Report: "Agent Teams env var added to `.claude/settings.local.json`"
     - If already present: no action needed (preserve existing value regardless of what it is)

## Phase 2: Status Assessment

| Status | Condition |
|--------|-----------|
| Auto-returned | Branch auto-return was executed in Phase 0 |
| Ongoing work | Not on main, unmerged commits exist |
| Clean start | On main, no uncommitted changes, no open PRs |
| Needs cleanup | Uncommitted changes present |

## Phase 3: Summary Report

```
## Session Start Report

**Plugin Version:** atdd-kit vX.Y.Z  <-- from check-plugin-version.sh
**Agent Teams:** Configured           <-- only if settings.local.json was created or updated in Phase 1-G
**Updated: v0.1.0 → v0.2.0**         <-- only if UPDATED
> (CHANGELOG diff here)              <-- only if UPDATED

### Plugin Sync  <-- only if UPDATED
| File | Status |
|------|--------|
| .github/ISSUE_TEMPLATE/development.yml | Updated |
| .github/pull_request_template.md | Updated |
| .claude/hooks/sim-pool-guard.sh | Updated (iOS) |

**Branch:** `<branch>` (<clean / uncommitted changes>)

### Previous Work  <-- only if ongoing work exists
- PR #XX: <title> -- <CI status> / <review status> / ⚠ CONFLICTING  <-- if mergeable == CONFLICTING

### Recent Activity (24h)  <-- only if recent activity exists
| Type | # | Title | When |
|------|---|-------|------|
| PR merged | #XX | <title> | 3h ago |
| Issue closed | #YY | <title> | 12h ago |

### Worktree Cleanup  <-- only if stale worktrees were found
| Worktree | Action |
|----------|--------|
| autopilot-123 | Pruned (orphaned) |

### Open Issues
| # | Title | Labels |
|---|-------|--------|

### Recommended Tasks
| Priority | Issue | Reason |
|----------|-------|--------|
```

### Task Recommendation Rules

**Step 1: Build exclusion list**
1. Collect all Issue numbers with `in-progress` label → EXCLUDE_SET
2. Collect all Issue numbers that have open PRs (from Phase 1-B) → add to EXCLUDE_SET

**Step 2: Filter and rank**
1. **Highest priority:** Open PRs with `mergeable == CONFLICTING` — recommend rebase with command example:
   ```bash
   git fetch origin main
   git checkout <branch>
   git rebase origin/main
   # After resolving conflicts
   git push --force-with-lease
   ```
2. Remove EXCLUDE_SET from open Issues
3. Rank remaining: bugs > features > refactoring > research
4. Apply priority labels if present: p1 > p2 > p3
