---
name: express
description: "Use when explicitly invoked via /atdd-kit:express for trivial, low-risk changes that do not require the full discover → plan → ATDD → review chain."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# express Skill — Fast Path for Trivial Changes

Shortened path for low-risk changes: Issue → implement → CI → merge. Full discover/plan/review chain bypassed. Issue-driven development, CI gates, and DEVELOPMENT.md processes are maintained.

See `docs/guides/express-mode.md` for OK/NG criteria.

---

## Step 1: Input Validation

- No issue number: "Express mode requires an issue number. Usage: `/atdd-kit:express <issue-number>`" → **STOP**.
- `gh issue view <number> --json number,title,state,labels`
  - Not found: "Issue #N not found." → **STOP**.
  - `state == "closed"`: "Issue #N is already closed." → **STOP**.
  - Has `in-progress`: "Issue #N is already in-progress. Cannot start Express mode." → **STOP**.

---

## Step 2: Express Applicability Check

Display the issue title and summary. Present OK/NG criteria from `docs/guides/express-mode.md`. Ask user to confirm qualification and provide rationale (which OK criterion applies).

<APPROVAL-GATE>
Do NOT proceed without explicit user approval and a stated rationale.
Implicit fallback is prohibited — user must confirm: (a) change qualifies under OK criteria, and (b) rationale is provided.
User declines: proceed to Step 3. User approves: record rationale and proceed to Step 4.
</APPROVAL-GATE>

---

## Step 3: Clean Abort (on Rejection)

- Do NOT create branch, PR, labels, or any changes.
- "Express mode cancelled. No changes made."
- **STOP.**

---

## Step 4: Escalation Check (Complexity Gate)

If during implementation the change exceeds Express OK criteria, STOP and report: "Change scope exceeds Express mode criteria. Use `/atdd-kit:autopilot <issue-number>` for the full chain." Do not continue in Express mode.

---

## Step 5: Lock Issue and Create Branch

1. Add `in-progress` label: `gh issue edit <number> --add-label "in-progress"`
2. Create branch from main: `git checkout main && git pull origin main && git checkout -b express/<number>-<slug>`
   - `<slug>` is a short kebab-case description derived from the issue title (max 5 words)

---

## Step 6: Implement the Change

Implement directly. No ATDD loop required. Mandatory per DEVELOPMENT.md:
- If change affects plugin behavior or adds a new file: bump version in `.claude-plugin/plugin.json`
- Add entry to `CHANGELOG.md` under `[Unreleased]` (not optional)

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

After creation, verify `express-mode` label exists: `gh label list | grep express-mode`
- Missing: "Label 'express-mode' not found. Run `/atdd-kit:setup-github` to create required labels." Wait before continuing.

Add label: `gh pr edit --add-label "express-mode"`

---

## Step 9: CI Gate

<HARD-GATE>
Do NOT merge until CI passes. No bypass path. CI is mandatory.
</HARD-GATE>

`gh pr checks --watch`

- CI passes: proceed to Step 10.
- CI fails: diagnose, fix, push, re-run. Do not merge until CI passes.

---

## Step 10: Merge and Close

1. Verify CI: `gh pr checks`
2. Merge: `gh pr merge --squash`
3. Cleanup: `git checkout main && git pull origin main && git branch -d express/<number>-<slug>`

Show: `"PR #XX merged (squash). Issue #YY auto-closed. Branch deleted. Switched to main."`

---

## Red Flags (STOP)

- Starting without explicit user approval (APPROVAL-GATE violation)
- Proceeding without user rationale
- Merging without CI green
- Missing `express-mode` label on PR
- PR body missing `## Express Mode` section with rationale
- Skipping version bump or CHANGELOG entry
- Continuing when scope has grown beyond OK criteria (escalate instead)
- Using `--admin` or any CI bypass

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
