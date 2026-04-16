---
name: session-start
description: "Session start report -- git status, PR/CI, Issue list, recommended tasks. Auto-invoked by other skills."
---

# Session Start Routine

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill entirely.
</SUBAGENT-STOP>

Run independent information-gathering steps **in parallel**. Phase 0 must complete **alone** first.

## Phase 0: Update Repository (run alone)

1. `git branch --show-current`
2. `git status --short`
3. **On main:** `git pull origin main --ff-only`
4. **Not on main:** Run branch auto-return logic (below)
5. **Stale Worktree Cleanup:** `git worktree list --porcelain`. If stale worktrees exist, run `git worktree prune`. Record for Phase 3 report.
6. `git log --oneline -5`

### Branch Auto-Return Logic

1. `git fetch origin main`
2. `git log --oneline origin/main..HEAD --no-merges`
3. 0 commits → `git checkout main && git pull origin main` (auto-return)
4. 1+ commits → `gh pr list --head <branch> --state merged`
5. Merged PR found → auto-return to main
6. No merged PR → report as ongoing work

## Phase 1: Information Gathering (parallel)

### A. GitHub Account Check
- `gh api user --jq .login`

### B. Open PRs and CI
1. `gh pr list --author @me --state open`
2. For open PRs → `gh pr view <number> --json title,state,reviewDecision,statusCheckRollup,mergeable`

### C. GitHub Issues
- `gh issue list --state open --limit 20`

### D. First-Time Setup (if workflow-config.yml missing)

If `.claude/workflow-config.yml` does not exist:

1. **Auto-detect platform:**
   - `*.xcodeproj`, `*.xcworkspace`, or `Package.swift` → `ios`
   - `package.json` → `web`
   - Neither → "No platform detected. Run `/atdd-kit:setup-ios` or `/atdd-kit:setup-web`."
2. **Confirm** with user — read `${CLAUDE_PLUGIN_ROOT}/addons/<platform>/addon.yml` and show:
   ```
   <Platform> project detected. The following will be set up:

   MCP Servers:  <list mcp_servers keys from addon.yml>
   Hooks:        <list matcher patterns from addon.yml hooks>
   Deploy Files: <list dest paths from addon.yml deploy>
   Skills:       <list skills from addon.yml>

   Proceed? [Y/n]
   ```
3. **Process addon:**
   - **MCP servers**: Merge `mcp_servers` into `.mcp.json` (create if missing, preserve existing)
   - **Deploy files**: Copy each `deploy` entry from `${CLAUDE_PLUGIN_ROOT}/addons/<platform>/<src>` to `<dest>`
   - **Hooks**: Add `hooks.PreToolUse` entries to `.claude/settings.json` (preserve existing)
   - **Guidance**: Display the `guidance` text
4. **Write** `.claude/workflow-config.yml`:
   ```yaml
   platform: [<detected-platform>]
   ```
5. Continue to Phase 1-E

### E. Plugin Version Check
- Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-plugin-version.sh "${CLAUDE_PLUGIN_ROOT}" "${HOME}/.claude/plugin-cache"`
- Parse output:
  - `FIRST_RUN`: Show current version in report.
  - `NO_UPDATE`: No action.
  - `UPDATED`: 5 lines: `UPDATED`, `<old>`, `<new>`, `VERSIONS: <N>`, `BREAKING: <M>`. Parse counts for report.

### E2. Auto-Sync on Plugin Update (only if UPDATED)

Read `.claude/workflow-config.yml` for `platform`. For each platform:

1. Read `${CLAUDE_PLUGIN_ROOT}/addons/<platform>/addon.yml`
2. Copy each `deploy` entry (overwrite without asking)

Always-sync files (all platforms):

| Plugin Source | Project Destination |
|-------------|-------------------|
| `templates/issue/en/*.yml` | `.github/ISSUE_TEMPLATE/*.yml` |
| `templates/issue/ja/*.yml` | `.github/ISSUE_TEMPLATE/*-ja.yml` |
| `templates/pr/en/pull_request_template.md` | `.github/pull_request_template.md` |

Record synced files for the Phase 3 report.

### F. Recent Activity (24h)

In parallel:
1. `gh pr list --state merged --search "merged:>=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)" --limit 10 --json number,title,mergedAt`
2. `gh issue list --state closed --json number,title,closedAt --limit 10` — filter to last 24h

If both results are empty, skip the Recent Activity section.

### G. Agent Teams Environment Check

Ensure `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` (per-machine, gitignored).

1. **Read** `.claude/settings.local.json`:
   - Missing → create with:
     ```json
     {
       "env": {
         "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
       }
     }
     ```
     Report: "Agent Teams env var configured."
   - Invalid JSON → warn: "`.claude/settings.local.json` contains invalid JSON — fix manually." Skip (do not block).
   - Valid JSON, key missing → deep-merge `{"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}}`, preserving all other keys. Report: "Agent Teams env var added."
   - Key present → no action.

## Phase 2: Status Assessment

| Status | Condition |
|--------|-----------|
| Auto-returned | Branch auto-return ran in Phase 0 |
| Ongoing work | Not on main, unmerged commits exist |
| Clean start | On main, no uncommitted changes, no open PRs |
| Needs cleanup | Uncommitted changes present |

## Phase 3: Summary Report

```
## Session Start Report

**Plugin Version:** atdd-kit vX.Y.Z
**Agent Teams:** Configured           <-- only if settings.local.json was created or updated in Phase 1-G
**Updated: v<old> → v<new> (<N> versions, <M> breaking changes). See CHANGELOG.md for details.**  <-- only if UPDATED
**⚠ BREAKING CHANGE detected**      <-- only if UPDATED and BREAKING > 0

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
1. Issues with `in-progress` label → EXCLUDE_SET
2. Issues with open PRs (Phase 1-B) → add to EXCLUDE_SET

**Step 2: Filter and rank**
1. **Highest priority:** PRs with `mergeable == CONFLICTING` — recommend rebase:
   ```bash
   git fetch origin main
   git checkout <branch>
   git rebase origin/main
   # After resolving conflicts
   git push --force-with-lease
   ```
2. Remove EXCLUDE_SET from open Issues
3. Rank remaining: bugs > features > refactoring > research
4. Apply priority labels: p1 > p2 > p3
