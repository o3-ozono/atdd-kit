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

### D. First-Time Setup and Legacy Migration (.claude/config.yml)

This phase handles (a) first-time project setup and (b) migration from the legacy `.claude/workflow-config.yml` to `.claude/config.yml`. The single source of truth for project-side settings is now `.claude/config.yml` (merged from the old `workflow-config.yml` `platform` + the retired plugin-side `config/spawn-profiles.yml`). All migration logic is idempotent and logs its outcome into the Phase 3 sync report (migrated / skipped / merged / no-op).

#### D-1. Legacy migration branches (AC7)

Evaluate the two files and act per the branch table below. All branches are idempotent: running this phase twice on the same project state is a no-op on the second run.

| `.claude/workflow-config.yml` (old) | `.claude/config.yml` (new) | Action | Sync report |
|---|---|---|---|
| present | absent | **old-only** — write new file (AC11 placeholder template included), then delete old. If the write fails, leave old in place (no partial state). | `migrated: workflow-config.yml → config.yml` |
| absent | present | **new-only** — no-op. | `skipped: config.yml already present` |
| present | present, `platform` key present in new | **both-exist, platform present** — delete old only; do not merge (duplicate merge is skipped to avoid silently overwriting a user edit). | `merged-skipped: config.yml already owns platform; deleted old workflow-config.yml` |
| present | present, `platform` key absent in new | **both-exist, platform absent** — merge the old `platform` value into new, then delete old. | `merged: platform from old workflow-config.yml → config.yml; deleted old` |
| absent | absent | **both-absent** — no-op (first-time setup runs in D-2 next). | (no entry; D-2 may add one) |

The write-then-delete ordering (old-only and both-exist/platform-absent branches) keeps the process crash-safe: if the process dies between the write and the delete, the next session re-enters D-1 and the both-exist branch idempotently completes the delete without re-writing.

#### D-2. First-time setup (only when both files are absent)

If both `.claude/workflow-config.yml` and `.claude/config.yml` are absent after D-1:

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
4. **Write** `.claude/config.yml` using the AC11 placeholder template spec below.
5. Continue to Phase 1-E

#### D-3. AC11 — `.claude/config.yml` placeholder template (idempotent)

Every write to `.claude/config.yml` under D-1 (old-only migration) and D-2 (first-time setup) MUST include the `spawn_profiles` placeholder template unless the file already has a `spawn_profiles` section (commented or active) — skip writing the placeholder in that case so the process is idempotent (running the phase twice never duplicates or overwrites the block).

Requirements the placeholder template must meet:

- Commented-out (every line prefixed with `# `) so YAML parsers ignore it until the user opts in.
- Enumerates all 6 roles (developer / qa / tester / reviewer / researcher / writer), each with at least one example line illustrating the `{ model: sonnet|opus|haiku }` map shape.
- Includes a note that unspecified roles inherit the session default (Agent tool `model` parameter omitted), so partial definitions are valid.
- Yields valid YAML after the user uncomments the lines (verified by the DoD manual smoke test: `python3 -c "import yaml; yaml.safe_load(open('.claude/config.yml'))"`).

Reference template (embed verbatim; the leading `# ` on every line ensures the section stays inert until the user opts in):

```yaml
platform:
  - <detected-platform>

# spawn_profiles:
#   # custom: optional per-project spawn profile applied by /atdd-kit:autopilot
#   # when no --profile flag is supplied. Define only the roles you want to
#   # override — roles not listed here inherit the session default (model
#   # parameter omitted from the Agent tool call).
#   custom:
#     developer:  { model: sonnet }
#     qa:         { model: sonnet }
#     tester:     { model: sonnet }
#     reviewer:   { model: opus }
#     researcher: { model: sonnet }
#     writer:     { model: sonnet }
```

### E. Plugin Version Check
- Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-plugin-version.sh "${CLAUDE_PLUGIN_ROOT}" "${HOME}/.claude/plugin-cache"`
- Parse output:
  - `FIRST_RUN`: Show current version in report.
  - `NO_UPDATE`: No action.
  - `UPDATED`: 5 lines: `UPDATED`, `<old>`, `<new>`, `VERSIONS: <N>`, `BREAKING: <M>`. Parse counts for report.

### E2. Auto-Sync on Plugin Update (only if UPDATED)

Read `.claude/config.yml` for `platform`. For each platform:

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
