# AC Review: Developer Perspective

**Issue:** #2 — feat: session-start で Agent Teams 環境変数を自動設定する
**Reviewer:** Developer Agent
**Date:** 2026-04-11

## Overall Assessment

Draft AC set is technically sound and well-scoped. The core approach — adding a check step to session-start that runs every session — is correct. However, there are architectural concerns about the target file (`settings.json` vs `settings.local.json`), JSON manipulation reliability, and a missing edge case for malformed JSON.

**Verdict: Conditionally PASS** — recommend modifications below before finalizing.

## Per-AC Feedback

### AC1: Every-session auto-configuration — PASS with modification

**Feasibility:** High. Adding a new Phase 1 sub-step (e.g., Phase 1-G) to session-start SKILL.md is straightforward. The existing Phase 1 structure already has A-F parallel steps, and a new parallel step fits cleanly.

**Concern — target file:** The draft says `.claude/settings.json`, but this repo's `.claude/settings.json` is **committed to git** (not in `.gitignore`). The `env` block with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is a **runtime environment variable** — it should go in `.claude/settings.local.json`, which is gitignored (confirmed: `.gitignore` line 5). This matches the existing pattern where `GH_TOKEN` is set in `settings.local.json` per the user's `github-accounts.md` rule.

**Why this matters:**
1. `settings.json` is shared across all clones via git — injecting env vars there pollutes the shared config
2. `settings.local.json` is per-machine, gitignored, and already the established pattern for env vars
3. Phase 1-D (First-Time Setup) already writes hooks to `settings.json`, but hooks are structural (shared). Env vars are per-machine (local).

**Recommendation:** Change target from `.claude/settings.json` to `.claude/settings.local.json`. This is a semantic correction, not a scope change.

### AC2: Preserve existing settings — PASS

**Feasibility:** High. JSON merge logic (read, parse, deep-merge `env` key, write back) is a standard LLM operation. The `jq` tool or Claude's native JSON understanding can handle this.

**Edge case to add:** If `env` key exists but contains other entries (e.g., `GH_TOKEN`, `DISCORD_BOT_TOKEN`), those must be preserved. The AC says "other env entries preserved" which covers this, but the implementation instruction should be explicit about deep merge vs overwrite.

### AC3: settings.json non-existence — PASS with modification

**Feasibility:** High. Creating a new JSON file with minimal content is trivial.

**Modification needed:** If we switch to `settings.local.json` (per AC1 recommendation), this AC should say `settings.local.json`. The created file should contain only the `env` block — do not create a full `settings.json` structure (no `hooks`, `attribution`, etc.) in the local file.

**Edge case:** `.claude/` directory itself might not exist (fresh clone without any Claude Code setup). The step should ensure `mkdir -p .claude` before writing.

### AC4: autopilot Prerequisites Check fallback — PASS with minor edit

**Feasibility:** High. The Prerequisites Check section already exists in `commands/autopilot.md` (lines 241-252). Adding a specific error message for missing Agent Teams env var is a simple text addition.

**Current state:** The existing check at line 249-250 says "Agent Teams tools (TeamCreate, SendMessage) not found. Cannot proceed." This is good but doesn't tell the user **why** the tools are missing or **how to fix it**. AC4's proposed message is better — it gives actionable guidance.

**Concern — ToolSearch timing:** The existing check uses ToolSearch to verify `TeamCreate`/`SendMessage` are resolvable. If the env var is unset, these tools simply won't appear in the deferred tool list. The check is already correct in mechanism; AC4 just improves the error message. No new check logic needed.

**Minor edit:** The error message should reference `settings.local.json` (not `settings.json`) if AC1's recommendation is accepted.

### AC5: Documentation of prerequisite — PASS

**Feasibility:** Trivial. Adding a line to docs is minimal effort.

**Current state:** `docs/workflow-detail.md:69` already says "Requires: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`" — so this is partially done. The AC should verify this existing mention is sufficient or if additional locations need updating (e.g., README, DEVELOPMENT.md).

**Suggestion:** Check if `commands/autopilot.md` Prerequisites section also needs this documented (it currently lists `workflow-config.yml` and agent definitions, but not the env var).

## Suggested Modifications

### M1: Target `settings.local.json` instead of `settings.json`

All ACs referencing `settings.json` should use `settings.local.json`. Rationale: env vars are per-machine configuration, not shared project configuration. This aligns with existing `GH_TOKEN` pattern.

### M2: Add AC for malformed JSON handling

**Missing edge case:** If `settings.local.json` exists but contains invalid JSON (e.g., user hand-edited and introduced syntax error), the merge will fail. Add an AC:

> **AC6: Malformed settings.local.json recovery**
> - Given: `.claude/settings.local.json` exists but contains invalid JSON
> - When: session-start executes the Agent Teams env check
> - Then: Report warning "settings.local.json contains invalid JSON — cannot auto-configure Agent Teams env var. Please fix the file manually." and continue session-start (do not block other phases)

### M3: Clarify Phase placement in session-start

The draft says "Phase 1-D2 or similar" but this should be a new parallel step **Phase 1-G** (since A-F are taken). It must NOT be inside Phase 1-D (First-Time Setup) because D only runs when `workflow-config.yml` is missing. The new step must run unconditionally every session.

### M4: Add `commands/autopilot.md` Prerequisites update to AC5

The Prerequisites section in `autopilot.md` should list the env var alongside the existing prerequisites (`workflow-config.yml`, agent definitions).

## Implementation Complexity Estimate

### Files to change

| File | Change | Complexity |
|------|--------|------------|
| `skills/session-start/SKILL.md` | Add Phase 1-G (Agent Teams env check) | Low — add ~15 lines to Phase 1 section |
| `commands/autopilot.md` | Update Prerequisites Check error message + add env var to Prerequisites list | Low — modify ~5 lines |
| `docs/workflow-detail.md` | Verify existing mention is sufficient (line 69) | Minimal — possibly no change needed |
| `README.md` / `README.ja.md` | Add env var to prerequisites if not mentioned | Low |
| `tests/` | Add new BATS test file | Low — pattern is well-established |

**Total: 4-5 files, all low complexity.**

### Test approach

New BATS test file `tests/test_session_start_agent_teams_env.bats` following existing patterns (e.g., `test_session_start_version.bats`):

1. Verify session-start SKILL.md mentions `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
2. Verify the step is in Phase 1 (not inside Phase 1-D conditional)
3. Verify `settings.local.json` is the target (not `settings.json`)
4. Verify autopilot.md Prerequisites mentions the env var
5. Verify autopilot.md error message includes actionable guidance
6. Verify docs/workflow-detail.md mentions the requirement

### Risk assessment

**Low risk.** Changes are additive (new step in session-start, improved error message in autopilot). No existing behavior is modified. The session-start skill already handles JSON manipulation in Phase 1-D (hooks in settings.json), so the pattern is established.
