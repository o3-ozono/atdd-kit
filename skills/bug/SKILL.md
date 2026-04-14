---
name: bug
description: "Auto-triggers on bug/defect/error reports. Fires on keywords like 'bug', 'broken', 'crash', 'error', 'not working', 'display issue', etc."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.
This ensures duplicate Issues are caught, related PR states are known, and branch status is clear.

# Bug Report Pipeline

Takes a bug report from the user and drives it through Issue creation -> reproduction -> evidence collection -> fix proposal.

## Auto-trigger Conditions

Start this flow automatically (even without explicit invocation) when:
- User reports something like "bug", "broken", "not working", "crash", "error", "display issue", etc.
- Japanese keywords (literal — match these tokens in user input): "バグ", "不具合", "おかしい", "壊れている", "動かない", "表示がおかしい", "落ちる", "クラッシュ", "エラー", "止まる", "反応しない", "フリーズ"
- Screenshots or videos are attached
- An existing Issue has the `type:bug` label and the user asks for a fix

When unsure, ask: "Should I triage this as a bug report?"

## Phase 1: Intake

Ask one question at a time (never batch multiple questions):
1. What happened? (symptom)
2. What did you expect?
3. Steps to reproduce?
4. Environment? (OS, device, version)
5. Do you have screenshots or logs?

## Phase 2: Issue Creation

- Create Issue following the `${CLAUDE_PLUGIN_ROOT}/templates/issue/en/bug-report.yml` format
- Register with `gh issue create`
- Do NOT add `in-progress` label (it is added when work actually starts, e.g. discover)

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

This enables discover to skip redundant questions already answered during bug intake.

## Phase 3: Existing Test Check

- Search for and run related existing tests
- Record test results as an Issue comment

## Phase 4: Reproduction

- Read `platform` from `.claude/workflow-config.yml` (array of platforms)
- Reproduce on each applicable platform:
  - If `"ios"` in platform: reproduce on simulator
  - If `"web"` in platform: reproduce in browser
  - Other: use the appropriate method
- For multi-platform projects, reproduce on all listed platforms
- If reproduced: record evidence (screenshots/logs) as an Issue comment
- If not reproduced: report this and ask the user for more information

## Phase 5: Evidence Collection

Collect evidence based on the nature of the bug:

| Bug Nature | Evidence Type |
|-----------|--------------|
| State issue (wrong display, stale data) | Screenshot |
| Action issue (crash on tap, navigation failure) | Screen recording |
| Common (all bugs) | Log capture + stack trace |

- Collect related logs
- Record stack traces
- Record environment details
- Post all evidence as an Issue comment

## Fix Proposal Format

After investigation, present the proposal to the user:

```
## Fix Proposal

**Classification:** A/B/C -- <explanation>
**Root Cause:** <what is actually broken and why>
**Fix Location:** <file:line>
**Parallel Patterns:** <N other occurrences found / none>
**Effort:** Small / Medium / Large
**User Impact:** High / Medium / Low -- <reason>
**Priority:** P1 / P2 / P3
```

Then use AskUserQuestion with:
- header: "Fix?"
- options:
  1. "(Recommended) Proceed with fix"
  2. "Revise proposal"
- multiSelect: false

Recommended: Proceed with fix — reply 'ok' to accept, or provide alternative

## Next Step

"Initial bug triage complete. Running `atdd-kit:discover` to define the fix approach."
-> Invoke the discover skill (bug mode)
