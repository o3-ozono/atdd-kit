---
name: ship
description: "Use after verify passes to finalize the PR and drive it through review to merge."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# ship Skill

<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--autopilot` (user invoked directly via slash command):
- Display message: "This skill is autopilot-only. Use `/atdd-kit:autopilot <number>` instead."
- **STOP.** Do not proceed with execution.
If ARGUMENTS contains `--autopilot` (invoked by autopilot): skip this guard silently.
</AUTOPILOT-GUARD>

<HARD-GATE>
Do NOT proceed to Step 8 (Completion Decision) or Step 9 (Merge) until the review cycle in Step 7 is complete. After adding the `ready-for-PR-review` label, you MUST wait for one of the following before proceeding:
- The `ready-for-PR-review` label has been removed (indicating review is complete/approved)
- A review PASS comment has been posted by the QA process
Merging without confirmed review completion is prohibited regardless of perceived simplicity or autonomy level.
</HARD-GATE>

## State Gate (required)

1. **Check `in-progress` label:** `gh issue view <number> --json labels --jq '[.labels[].name] | index("in-progress")'`
   - Present: proceed.
   - Missing: STOP. "Issue #N does not have `in-progress` label. Complete `atdd` → `verify` first."
2. **Check implementation branch:** Verify current branch is not `main`.
   - On `main`: STOP. "Cannot ship from main. Check out the implementation branch first."

## Prerequisites

- All ACs verified (`verify` complete)
- Working branch with Draft PR created (from `atdd`)
- All tests passing, build clean

## Flow

### Step 1: Convert Draft PR to Ready

- `git push` (if not already pushed)
- `gh pr ready`

### Step 2: Generate PR Description

```markdown
Closes #<issue-number>

## Goal
[1-2 sentences: what this PR achieves]

## Non-goal
[What is explicitly out of scope for this PR]

## Background
[Why this change is needed — summarize the motivation, not just "see Issue #N"]

## Changes

| File | Role |
|------|------|
| path/to/file | What this file does |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| [choice made] | [why] |

## Test Plan
- [x] AC1: [name] -- [test type] PASS
- [x] AC2: [name] -- [test type] PASS
- [x] Build: zero warnings
- [x] Lint: clean
- [x] All existing tests: PASS
```

Update PR body: `gh pr edit --body "..."`

### Step 3: Add Inline Comments

Use `gh api` to post PR review comments: file header comments for non-obvious files, language-specific feature explanations for non-specialists. Skip auto-generated files.

### Step 4: Add Labels

- Add matching `type:` label from Issue: `gh pr edit --add-label "type:..."`
- Add `ready-for-PR-review` label: `gh pr edit --add-label "ready-for-PR-review"`
- Remove `in-progress` if present: `gh pr edit --remove-label "in-progress"`

### Step 5: CI Check

- `gh pr checks --watch`
- CI fails: diagnose, fix, push, wait again
- CI passes: proceed

### Step 6: UI Change Detection (if applicable)

- `git diff origin/main --name-only | grep '__Snapshots__/.*\.png'`
- Snapshot diffs present: this is a UI change PR

### Step 7: Review Cycle

After `ready-for-PR-review` label is set:

1. Wait for review (autopilot QA or human) to complete
2. Check label state with `gh pr view <PR> --json labels`:
   - `needs-pr-revision` added: fix issues, push, remove `needs-pr-revision`, re-add `ready-for-PR-review`, return to step 1
   - `ready-for-PR-review` removed: review complete → Step 8
   - Review PASS comment on PR: review complete → Step 8
3. Prohibited: do NOT offer "Merge" or "Skip review" via AskUserQuestion; do NOT proceed to Step 8 until a completion signal is confirmed.

### Step 8: Completion Decision

**Prerequisite — verify review cycle (Step 7) is complete:**
- Run: `gh pr view <PR> --json comments --jq '.comments[].body'` and check for review PASS comment
- OR confirm `ready-for-PR-review` label has been removed from the PR
- If NEITHER condition is met: DO NOT proceed. Return to Step 7 and wait for review completion.

Before merging, present the user with structured options:

```
PR is ready. How to proceed?

1. **Merge** -- Squash-merge to main (default)
2. **Keep** -- Leave PR open for further work
3. **Discard** -- Close PR and delete branch (destructive)

[1 / 2 / 3]
```

- **Option 1 (Merge):** Proceed to merge flow below
- **Option 2 (Keep):** Report status and exit skill
- **Option 3 (Discard):** Confirm with user ("Are you sure? This deletes the branch."), then `gh pr close --delete-branch`

### Step 9: Merge

- Check conflicts: `gh pr view <PR> --json mergeable,mergeStateStatus`
  - `mergeable == CONFLICTING`: do NOT merge. Ask user to approve rebase (fetch + rebase + force-with-lease). User declines → stop.
- Verify CI: `gh pr checks`
- Check `blocked-by: #N` — verify dependency is closed
- Merge: `gh pr merge --squash`
- Cleanup: `git checkout main && git pull origin main && git branch -d <branch>`

## Status Output

**Autopilot mode only** (ARGUMENTS contains `--autopilot`). Skip in standalone mode.

Output a `skill-status` fenced code block as the **last element** of your response at every terminal point.

Terminal points:
- **COMPLETE:** PR merged successfully.
- **PENDING:** Waiting for user decision (Merge / Keep / Discard in Step 8).
- **BLOCKED:** State Gate failed or review not complete.
- **FAILED:** Unrecoverable error (e.g., persistent conflict, CI broken).

```skill-status
SKILL_STATUS: COMPLETE | PENDING | BLOCKED | FAILED
PHASE: ship
RECOMMENDATION: <next action or error description in one sentence>
```

Examples:

```skill-status
SKILL_STATUS: COMPLETE
PHASE: ship
RECOMMENDATION: PR #60 merged. Issue #58 auto-closed.
```

```skill-status
SKILL_STATUS: BLOCKED
PHASE: ship
RECOMMENDATION: PR review not yet confirmed. Wait for review PASS comment or ready-for-PR-review label removal.
```

See `docs/guides/skill-status-spec.md` for full field definitions, BLOCKED vs FAILED distinction, and autopilot action matrix.

### Step 10: Report

```
PR #XX merged.
- Issue #YY -> auto-closed
- Branch <branch> -> deleted
- Switched to main
```

## Red Flags (STOP)

- Merging without CI green
- Merging with unresolved review comments
- Merging when a `blocked-by` dependency is still open
- Merging when PR has merge conflicts with main
- Force pushing without user approval
- Skipping review cycle / merging without review completion confirmed
- Offering "Merge" or "Skip review" options in AskUserQuestion during Step 7
- Proceeding to Step 8 before review PASS is confirmed
- Skipping PR description or inline comments

## Constraints

- Always `--squash` merge (1 PR = 1 commit)
- Never skip CI check
- Never skip review cycle -- QA process handles this even for solo developers
- Never force push without explicit user approval
- When merging your own PR, merge directly without explanation.
