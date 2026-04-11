---
name: ship
description: "Use after verify passes to finalize the PR and drive it through review to merge."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# ship Skill

<HARD-GATE>
Do NOT proceed to Step 8 (Completion Decision) or Step 9 (Merge) until the review cycle in Step 7 is complete. After adding the `ready-for-PR-review` label, you MUST wait for one of the following before proceeding:
- The `ready-for-PR-review` label has been removed (indicating review is complete/approved)
- A review PASS comment has been posted by the QA process
Merging without confirmed review completion is prohibited regardless of perceived simplicity or autonomy level.
</HARD-GATE>

## State Gate (required)

Before starting the ship flow, check the Issue state:

1. **Check `in-progress` label:** `gh issue view <number> --json labels --jq '[.labels[].name] | index("in-progress")'`
   - If present: proceed to ship Flow.
   - If missing: STOP. Report: "Issue #N does not have `in-progress` label. Complete `atdd` → `verify` first."
2. **Check implementation branch:** Verify the current branch is not `main`. Ship must run on the implementation branch.
   - If on `main`: STOP. Report: "Cannot ship from main. Check out the implementation branch first."

## Prerequisites

- All ACs verified (`verify` skill completed)
- Working branch with Draft PR already created (from `atdd` skill)
- All tests passing, build clean

## Flow

### Step 1: Convert Draft PR to Ready

- Push all commits if not already pushed: `git push`
- Update PR from draft to ready: `gh pr ready`

### Step 2: Generate PR Description

Generate PR description:

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

Use `gh api` to post PR review comments:
- File header comments explaining role/purpose for non-obvious files
- Language-specific features explained for non-specialists
- Skip auto-generated files

### Step 4: Add Labels

- Add matching `type:` label from Issue: `gh pr edit --add-label "type:..."`
- Add `ready-for-PR-review` label: `gh pr edit --add-label "ready-for-PR-review"`
- Remove `in-progress` if present: `gh pr edit --remove-label "in-progress"`

### Step 5: CI Check

- Wait for CI: `gh pr checks --watch`
- If CI fails: diagnose, fix, push, wait again
- If CI passes: proceed

### Step 6: UI Change Detection (if applicable)

- Run: `git diff origin/main --name-only | grep '__Snapshots__/.*\.png'`
- If snapshot diffs exist: this is a UI change PR

### Step 7: Review Cycle

After `ready-for-PR-review` label is set:

1. **Wait for review:** After setting `ready-for-PR-review` label, wait for the review process (autopilot QA or human) to complete
2. **Check review result:** Periodically check label state with `gh pr view <PR> --json labels`:
   - If `needs-pr-revision` label added: read review comments, fix issues, push, remove `needs-pr-revision`, re-add `ready-for-PR-review`, return to step 1
   - If `ready-for-PR-review` label removed: review complete, proceed to Step 8
   - If review PASS comment posted on the PR: review complete, proceed to Step 8
3. **Prohibited actions during Step 7:**
   - Do NOT use AskUserQuestion to offer "Merge", "Skip review", or any option that bypasses the review cycle
   - Do NOT proceed to Step 8 until one of the review completion signals above is confirmed
   - The only permitted user interaction is asking for help resolving review comments

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

- Check for merge conflicts: `gh pr view <PR> --json mergeable,mergeStateStatus`
  - If `mergeable == CONFLICTING`:
    - Do NOT merge
    - Ask user for approval to rebase:
      ```
      ⚠ Conflict detected. Cannot merge.

      May I run the following rebase?
        git fetch origin main
        git rebase origin/main
        # After resolving conflicts
        git push --force-with-lease
      ```
    - User approves → execute rebase, resolve conflicts interactively if needed, re-check CI, continue merge flow
    - User declines → stop skill
- Verify CI is green: `gh pr checks`
- Check `blocked-by: #N` in Issue/PR body -- if present, verify dependency is closed
- Merge with squash: `gh pr merge --squash`
- Clean up: `git checkout main && git pull origin main`
- Delete local branch: `git branch -d <branch>`

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

- Always use `--squash` for merge (keeps main history clean: 1 PR = 1 commit)
- Never skip CI check
- Never skip review cycle (even if you are the only developer -- the QA process handles this)
- Never force push without explicit user approval
- When merging your own PR, do not announce that you cannot approve it. Just merge directly without explanation.
