# Implementation Strategy: Developer

**Issue:** #2 — feat: session-start で Agent Teams 環境変数を自動設定する
**Author:** Developer Agent
**Date:** 2026-04-11

## 1. File Inventory and Changes

### 1.1 `skills/session-start/SKILL.md` (AC1, AC2, AC3)

**Current state:** Phase 1 has sub-steps A through F (plus E2). Phase 1-D runs conditionally (only if `workflow-config.yml` is missing). All other Phase 1 steps run in parallel.

**Change:** Add new sub-step **Phase 1-G: Agent Teams Environment Check** after Phase 1-F. This step runs unconditionally every session, in parallel with A-F.

**Insertion point:** After line 101 (end of Phase 1-F section), before line 103 (Phase 2 heading).

**Content to add (~20 lines):**

```markdown
### G. Agent Teams Environment Check

Ensure `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is configured in `.claude/settings.local.json` (per-machine, gitignored).

1. **Read** `.claude/settings.local.json`
   - If file does not exist: create `.claude/` directory if needed, then write:
     ```json
     {
       "env": {
         "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
       }
     }
     ```
     Report: "Agent Teams env var configured in `.claude/settings.local.json`"
   - If file exists but contains invalid JSON: report warning "`.claude/settings.local.json` contains invalid JSON — cannot auto-configure Agent Teams env var. Please fix the file manually." and skip this step (do not block session-start)
   - If file exists and valid JSON:
     - Check if `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` key exists
     - If missing: deep-merge `{"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}}` into existing content, preserving all other keys (especially other `env` entries like `GH_TOKEN`). Write back.
     - If present: no action needed (preserve existing value regardless of what it is)
```

**Why `settings.local.json`:** This file is gitignored (`.gitignore` line 5), is per-machine, and is the established pattern for env vars (see `github-accounts.md` where `GH_TOKEN` is set in `settings.local.json`). `settings.json` is committed to git — env vars do not belong there.

### 1.2 `commands/autopilot.md` (AC4, AC5)

**Current state:** Lines 238-256 contain Session Initialization section. Prerequisites Check (lines 240-250) has 3 checks: workflow-config.yml, agent definitions, Agent Teams tools (ToolSearch).

**Change A (AC5):** Add env var to Prerequisites list (line 11, after existing bullet points):

```markdown
## Prerequisites
- `.claude/workflow-config.yml` must exist (if missing, start a new session to trigger auto-setup)
- Agent definitions must exist in `${CLAUDE_PLUGIN_ROOT}/agents/` (po.md, developer.md, qa.md)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` must be set in `.claude/settings.local.json` `env` (auto-configured by session-start)
```

**Change B (AC4):** Improve the error message in Prerequisites Check step 3 (line 249-250). Replace:

```
If unavailable: STOP — "Agent Teams tools (TeamCreate, SendMessage) not found. Cannot proceed."
```

With:

```
If unavailable: STOP — "Agent Teams tools (TeamCreate, SendMessage) not found. Verify that `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in `.claude/settings.local.json` `env`, then restart the session."
```

### 1.3 `docs/workflow-detail.md` (AC5)

**Current state:** Line 69 already says `Requires: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. This is sufficient but lacks the file location.

**Change:** Update line 69 to:

```
Requires: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` `env` (auto-configured by session-start)
```

### 1.4 `tests/test_session_start_agent_teams_env.bats` (new file)

**New BATS test file** following existing patterns (e.g., `test_session_start_version.bats`, `test_session_start_adapters.bats`).

**Tests:**

```bash
#!/usr/bin/env bats

# AC1: session-start has Agent Teams env check step
@test "AC1: session-start mentions CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" {
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' skills/session-start/SKILL.md
}

@test "AC1: session-start targets settings.local.json not settings.json for env" {
  grep -q 'settings\.local\.json' skills/session-start/SKILL.md
}

@test "AC1: Agent Teams env check is in Phase 1 (parallel section)" {
  # Must be under Phase 1 heading, not inside Phase 1-D conditional
  awk '/^## Phase 1/,/^## Phase 2/' skills/session-start/SKILL.md | grep -q 'Agent Teams Environment Check'
}

@test "AC1: Agent Teams env check is not inside Phase 1-D conditional" {
  # Phase 1-D is conditional on workflow-config.yml missing
  # Agent Teams check must be a separate sub-step (G)
  awk '/^### G\./,/^###|^##/' skills/session-start/SKILL.md | grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
}

# AC2: existing settings preserved (instruction present)
@test "AC2: session-start instructs to preserve existing env entries" {
  grep -q 'preserv' skills/session-start/SKILL.md
}

@test "AC2: session-start instructs deep-merge not overwrite" {
  grep -q 'deep-merge\|merge' skills/session-start/SKILL.md
}

# AC3: settings.local.json non-existence handled
@test "AC3: session-start handles missing settings.local.json" {
  grep -q 'does not exist\|not exist' skills/session-start/SKILL.md
}

# AC4: autopilot error message includes env var guidance
@test "AC4: autopilot Prerequisites Check mentions env var in error message" {
  grep -A 5 'TeamCreate.*SendMessage.*not found\|not found.*TeamCreate' commands/autopilot.md | grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
}

@test "AC4: autopilot error message references settings.local.json" {
  grep -A 5 'TeamCreate.*SendMessage.*not found\|not found.*TeamCreate' commands/autopilot.md | grep -q 'settings\.local\.json'
}

# AC5: documentation includes prerequisite
@test "AC5: autopilot Prerequisites lists env var" {
  grep -A 5 '## Prerequisites' commands/autopilot.md | grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
}

@test "AC5: workflow-detail.md mentions env var requirement" {
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' docs/workflow-detail.md
}

@test "AC5: workflow-detail.md references settings.local.json" {
  grep -q 'settings\.local\.json' docs/workflow-detail.md
}
```

### 1.5 `CHANGELOG.md`

**Change:** Add entry under `[Unreleased]`:

```markdown
### Added
- session-start Phase 1-G: auto-configure `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` every session (#2)
- autopilot Prerequisites Check: actionable error message when Agent Teams tools are unavailable (#2)
```

### 1.6 `.claude-plugin/plugin.json`

**Change:** Bump version `1.0.0` -> `1.1.0` (new feature, backward-compatible).

### 1.7 `tests/README.md`

**Change:** Add entry for new test file `test_session_start_agent_teams_env.bats`.

## 2. Implementation Order

Dependencies flow downward. Steps at the same level can be done in parallel.

```
Step 1: skills/session-start/SKILL.md (AC1, AC2, AC3)
   |     -- This is the core change. All other files reference it.
   |
Step 2: commands/autopilot.md (AC4, AC5)  ||  docs/workflow-detail.md (AC5)
   |     -- These are independent of each other, depend on Step 1 design
   |
Step 3: tests/test_session_start_agent_teams_env.bats (all ACs)
   |     -- Tests verify steps 1 and 2
   |
Step 4: CHANGELOG.md  ||  .claude-plugin/plugin.json  ||  tests/README.md
         -- Housekeeping, no code dependency
```

**Per-AC mapping:**

| AC | Primary file | Step |
|----|-------------|------|
| AC1 | `skills/session-start/SKILL.md` (Phase 1-G) | 1 |
| AC2 | `skills/session-start/SKILL.md` (deep-merge instruction) | 1 |
| AC3 | `skills/session-start/SKILL.md` (non-existence handling) | 1 |
| AC4 | `commands/autopilot.md` (error message) | 2 |
| AC5 | `commands/autopilot.md` (Prerequisites) + `docs/workflow-detail.md` | 2 |

## 3. Technical Risks and Mitigations

### Risk 1: JSON merge reliability (Low)

**Risk:** LLM performing JSON deep-merge on `settings.local.json` could accidentally drop existing keys.

**Mitigation:** The instruction explicitly says "deep-merge, preserving all other keys (especially other `env` entries like `GH_TOKEN`)." The JSON structure is flat (only `env` with string values), so merging is trivial. The instruction also covers the invalid JSON edge case (warn and skip).

**Residual risk:** Acceptable. This is the same pattern as Phase 1-D which already merges hooks into `settings.json`. The LLM has proven capable of this.

### Risk 2: settings.local.json vs settings.json confusion (Medium)

**Risk:** Future contributors might add env vars to `settings.json` instead of `settings.local.json`.

**Mitigation:** The Phase 1-G instruction clearly specifies the target file. BATS tests explicitly verify `settings.local.json` is mentioned (not `settings.json` for env purposes). Documentation in Prerequisites and workflow-detail.md reinforces this.

### Risk 3: Circular dependency with session-start (None)

**Risk:** Could setting the env var in session-start cause issues if Agent Teams tools aren't available yet?

**Mitigation:** No risk. The env var is written to a file, not applied to the current process. It takes effect on the **next** session start when Claude Code reads `settings.local.json` at launch. This is by design — the first session won't have Agent Teams, but every session after that will.

### Risk 4: `.claude/` directory not existing (Low)

**Risk:** Fresh clone without any Claude Code setup might not have `.claude/` directory.

**Mitigation:** The instruction says "create `.claude/` directory if needed" (mkdir -p). In practice, Claude Code creates `.claude/` on first use, so this is extremely rare but handled.

## 4. Specific Change Locations

| File | Line(s) | Action |
|------|---------|--------|
| `skills/session-start/SKILL.md` | After line 101 (end of Phase 1-F), before line 103 (Phase 2) | Insert Phase 1-G section (~20 lines) |
| `commands/autopilot.md` | Line 11 (Prerequisites list) | Add env var bullet point |
| `commands/autopilot.md` | Line 250 (error message) | Replace with actionable message mentioning env var |
| `docs/workflow-detail.md` | Line 69 | Update to include file location |
| `tests/` | New file | Create `test_session_start_agent_teams_env.bats` |
| `CHANGELOG.md` | Line 8 (under `[Unreleased]`) | Add entries |
| `.claude-plugin/plugin.json` | Line 4 (version) | Bump to 1.1.0 |
| `tests/README.md` | Appropriate position | Add test file entry |

**Total: 7 files (5 modified, 1 new test file, 1 version bump). All changes are additive. No deletions or refactoring.**
