---
name: bug
description: "Auto-triggers on bug/defect/error reports. Fires on keywords like 'bug', 'broken', 'crash', 'error', 'not working', 'display issue', etc."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# Bug Report Pipeline

Drives a bug report through Issue creation → reproduction → evidence collection → fix proposal.

## Auto-trigger Conditions

- User reports "bug", "broken", "crash", "error", "not working", "display issue", etc.
- Japanese keywords: "バグ", "不具合", "おかしい", "壊れている", "動かない", "表示がおかしい", "落ちる", "クラッシュ", "エラー", "止まる", "反応しない", "フリーズ"
- Screenshots or videos attached
- Existing Issue with `type:bug` label and user requests a fix

When unsure, ask: "Should I triage this as a bug report?"

## Phase 1: Intake

Ask one question at a time: (1) What happened? (2) What did you expect? (3) Steps to reproduce? (4) Environment? (5) Screenshots or logs?

## Phase 2: Issue Creation

Create Issue using `${CLAUDE_PLUGIN_ROOT}/templates/issue/en/bug-report.yml` (-ja.yml is human-only). Register with `gh issue create`. Do NOT add `in-progress` label.

### Context Block Output

After creating the Issue, post a Context Block as an Issue comment:

```markdown
## Context Block

| Field | Value |
|-------|-------|
| task_type | bug |
| symptom | [what is happening] |
| reproduction | [steps to reproduce] |
| environment | [OS, device, version] |
| expected | [what should happen] |
| collected_info | [screenshots, logs, stack traces] |
```

Enables discover to skip questions already answered during intake.

## Phase 3: Existing Test Check

Search for and run related tests. Record results as Issue comment.

## Phase 4: Reproduction

Read `platform` from `.claude/workflow-config.yml`. Reproduce on each applicable platform. Record evidence as Issue comment; ask for more info if not reproduced.

## Phase 5: Evidence Collection

| Bug Nature | Evidence Type |
|-----------|--------------|
| State issue (wrong display, stale data) | Screenshot |
| Action issue (crash on tap, navigation failure) | Screen recording |
| All bugs | Log capture + stack trace |

Post evidence as Issue comment.

## Spec Citation in Root Cause Classification

Before writing Classification, load the spec via `lib/spec_check.sh`. The AC6 fallback matrix is shared across atdd / verify / bug:

1. `slug=$(bash lib/spec_check.sh derive_slug <issue>)` (set `SPEC_SLUG_OVERRIDE` for non-ASCII).
2. `bash lib/spec_check.sh spec_exists "$slug"`:
   - **present** → `bash lib/spec_check.sh read_acs "$slug"` and cite the governing AC number + `Given/When/Then` text as the Classification basis.
   - **absent, no prior implementation commits** → emit `[spec-warn] missing: ...` and treat as `Classification: A -- no spec found for <area>` (AC Gap). The missing spec itself is the gap; do not invent ad-hoc ACs.
   - **absent, Continuation Path (existing impl branch)** → emit `[spec-warn] continuation-fallback: ...` and cite Issue comment ACs as fallback.
3. `spec_persona` == `TBD…` → emit `[spec-warn] tbd-persona: ...` and continue citing spec ACs (do not block).

## Fix Proposal Format

```
## Fix Proposal

**Classification:** A/B/C -- <explanation citing spec AC or "no spec found for <area>">
**Spec AC:** docs/specs/<slug>.md#ACN (or "none — Classification A")
**Root Cause:** <what is broken and why>
**Fix Location:** <file:line>
**Parallel Patterns:** <N occurrences found / none>
**Effort:** Small / Medium / Large
**User Impact:** High / Medium / Low -- <reason>
**Priority:** P1 / P2 / P3
```

AskUserQuestion — header: "Fix?", options: "(Recommended) Proceed with fix", "Revise proposal"

Recommended: Proceed with fix — reply 'ok' to accept, or provide alternative

## Next Step

Show "Initial bug triage complete." and invoke discover skill (bug mode) via the Skill tool.
