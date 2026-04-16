---
name: express
description: "Use when explicitly invoked via /atdd-kit:express for trivial, low-risk changes that do not require the full discover → plan → ATDD → review chain."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# express Skill — Fast Path for Trivial Changes

Express mode provides a shortened path for low-risk changes: Issue → implement → CI → merge. The full discover/plan/review chain is bypassed. Issue-driven development, CI gates, and DEVELOPMENT.md mandatory processes are maintained.

See `docs/guides/express-mode.md` for the full OK/NG applicability criteria.

---

## Step 1: Input Validation

Verify that a valid issue number was provided as the first argument.

- If no issue number argument is given: output "Express mode requires an issue number. Usage: `/atdd-kit:express <issue-number>`" and **STOP**.
- Run: `gh issue view <number> --json number,title,state,labels`
  - If the issue does not exist or the command fails: output "Issue #N not found." and **STOP**.
  - If the issue state is `"closed"`: output "Issue #N is already closed. Express mode requires an open issue." and **STOP**.
  - If the issue has an `in-progress` label: output "Issue #N is already in-progress (locked by another session). Cannot start Express mode." and **STOP**.

---

## Step 2: Express Applicability Check

Display the issue title and summary to the user, then present the OK/NG criteria from `docs/guides/express-mode.md`.

Ask the user to confirm that this change qualifies as Express mode. Ask them to provide their rationale (which OK criterion applies).

<APPROVAL-GATE>
Do NOT proceed past this step without explicit user approval and a stated rationale.
Implicit fallback is prohibited — Express mode must never start without the user confirming: (a) the change qualifies under the OK criteria, and (b) a rationale is provided.
If the user declines or does not confirm: proceed to Step 3 (Clean Abort).
If the user approves and provides a rationale: record the rationale and proceed to Step 4.
</APPROVAL-GATE>

---

## Step 3: Clean Abort (on Rejection or Cancellation)

If the user declines the Express mode confirmation:

- Do NOT create a branch, PR, labels, or any changes.
- Output: "Express mode cancelled. No changes made, without creating branches or modifying issue state."
- **STOP.** The issue state, branch, and labels remain unchanged (no side effects).

---

## Step 4: Escalation Check (Complexity Gate)

Before implementing, briefly assess whether the change scope exceeds Express OK criteria.

If at any point during implementation the change turns out to be more complex than assessed (e.g., a typo fix requires API changes, a comment addition requires logic refactoring), you MUST:

1. STOP the current Express flow
2. Report: "The change scope exceeds Express mode criteria. Escalating to full workflow."
3. Instruct the user to restart with `/atdd-kit:autopilot <issue-number>` for the full discover → plan → ATDD chain.

Do not continue in Express mode when the change scope has grown beyond Express OK criteria.

---

## Step 5: Lock Issue and Create Branch

1. Add `in-progress` label: `gh issue edit <number> --add-label "in-progress"`
2. Create branch from main: `git checkout main && git pull origin main && git checkout -b express/<number>-<slug>`
   - `<slug>` is a short kebab-case description derived from the issue title (max 5 words)

---

## Step 6: Implement the Change

Implement the change directly. No separate plan or ATDD loop required.

Mandatory items that must be included (per DEVELOPMENT.md):
- If the change affects any plugin behavior or adds any new file: bump version in `.claude-plugin/plugin.json` (patch or minor as appropriate)
- Add entry to `CHANGELOG.md` under `[Unreleased]` (version bump and CHANGELOG update are not optional and cannot be skipped)

---

## Step 7: Commit and Push

Commit with a conventional commit message (per `docs/guides/commit-guide.md`):

```
git add <files>
git commit -m "<type>: <description> (#<issue-number>)"
git push -u origin express/<number>-<slug>
```

---

## Step 8: Create PR with Express Mode Markers

Create a PR:

```bash
gh pr create \
  --title "<type>: <description> (#<issue-number>)" \
  --body "..." \
  --label "express-mode"
```

The PR body must include:

```markdown
Closes #<issue-number>

## Goal
[1-2 sentences: what this PR achieves]

## Changes

| File | Role |
|------|------|
| path/to/file | What this file does |

## Express Mode

**Rationale:** <rationale provided by user in Step 2 — which OK criterion applies>

This PR was created via Express mode (`/atdd-kit:express`). Full discover/plan/review chain was bypassed because the change meets Express OK criteria. See `docs/guides/express-mode.md`.
```

After PR creation, check if the `express-mode` label exists in the repository:
- Run: `gh label list | grep express-mode`
- If the label does not exist: output "Label 'express-mode' not found. Run `/atdd-kit:setup-github` to create required labels, then re-add the label." and wait for user action before continuing.

Add the label once confirmed: `gh pr edit --add-label "express-mode"`

---

## Step 9: CI Gate

<HARD-GATE>
Do NOT merge until CI passes. CI gate is mandatory and cannot be skipped.
If CI fails: diagnose the failure, fix, push, and re-check. Do not merge with a failing CI.
</HARD-GATE>

Wait for CI to complete:

```bash
gh pr checks --watch
```

- If CI passes: proceed to Step 10.
- If CI fails: diagnose the issue, fix, push. Re-run `gh pr checks --watch`. Do not merge until CI passes.

There is no bypass path (no `--admin` or other override). CI must pass.

---

## Step 10: Merge and Close

Once CI passes:

1. Verify CI is green: `gh pr checks`
2. Merge with squash: `gh pr merge --squash`
3. Clean up: `git checkout main && git pull origin main`
4. Delete local branch: `git branch -d express/<number>-<slug>`

Report:
```
PR #XX merged (squash).
- Issue #YY -> auto-closed
- Branch express/<number>-<slug> -> deleted
- Switched to main
```

---

## Red Flags (STOP)

- Starting Express mode without explicit user approval (APPROVAL-GATE violation)
- Proceeding without a stated rationale from the user
- Merging without CI green
- Merging when `express-mode` label is missing from the PR
- Merging when PR body does not have `## Express Mode` section with rationale
- Skipping version bump or CHANGELOG entry
- Continuing Express mode when the change scope has grown beyond OK criteria (escalate instead)
- Adding `--admin` or any CI bypass to force-merge

---

## Status Output

Output a `skill-status` fenced code block as the **last element** of your response at every terminal point:

- **COMPLETE:** PR merged successfully.
- **PENDING:** Waiting for user approval (Step 2) or CI (Step 9).
- **BLOCKED:** Validation failed (Step 1) or user declined (Step 3).
- **FAILED:** Unrecoverable error.

```skill-status
SKILL_STATUS: COMPLETE | PENDING | BLOCKED | FAILED
PHASE: express
RECOMMENDATION: <next action or error description in one sentence>
```
