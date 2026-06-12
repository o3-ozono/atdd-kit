---
name: express
description: "Use when explicitly invoked via /atdd-kit:express <issue> for trivial, documentation-grade changes (README edits, typo fixes, gitignore additions) with no functional breakage risk."
---

# Express Skill — Lightweight Fast Path

For trivial, documentation-grade changes with no functional breakage risk.
Skips PRD / User Stories / Plan / AT / structured review.
Preserves Issue-driven governance and CI gate.

## Step 1: Input Validation

1. Require an Issue number. If none provided: **STOP** — output:
   ```
   Error: Issue number required. Usage: /atdd-kit:express <issue-number>
   ```
2. Run `gh issue view <N>` to validate:
   - **not found** → STOP: "Issue #N not found."
   - **closed** → STOP: "Issue #N is already closed."
   - **has `in-progress` label** → STOP: "Issue #N is already in-progress in another worktree."

## Step 2: Criteria Check and Activation Approval

### Applicability Criteria

**OK — express applies:**

| Category | Examples |
|----------|---------|
| docs/README edits | Add a section, fix wording, update a link |
| typo fixes | Spelling errors in docs, comments, string literals (non-logic) |
| comment updates | Code comment clarity, inline doc corrections |
| gitignore additions | Add patterns, no logic change |
| version bump only | Bump a dependency version in a manifest with no behavior change |

**NG — express does NOT apply:**

| Category | Examples |
|----------|---------|
| New feature | Any new capability or endpoint |
| Behavior change | Altering logic, output format, or API surface |
| Dependency addition | New package or tool introduced |
| CI / hooks change | Modifying workflows, hooks, scripts |
| Security impact | Auth, permissions, secrets handling |

When in doubt: fall back to the full flow via `/atdd-kit:defining-requirements <issue-number>`.

### Activation Approval

<APPROVAL-GATE>
Present the Issue title and the matching OK criterion to the user. Ask:

> This Issue appears to qualify for express mode (matched criterion: _<criterion>_).
> Proceed with express? [Y/n]

Do NOT start implementation until the user explicitly approves and states which OK criterion applies.
If the user declines, guide to `/atdd-kit:defining-requirements <issue-number>` instead.
</APPROVAL-GATE>

## Step 3: Implementation — Shortest Path

Express does NOT create any intermediate artifacts under `docs/issues/<NNN>/`
(no PRD, no user stories, no plan, no acceptance-tests, no review report).

1. Create branch: `git checkout -b express/<N>-<slug>`
2. Implement the change (scope: only what qualifies as OK above).
3. **Scope overflow check** — if the diff touches source files beyond documentation-grade changes (e.g., logic files, CI config, hooks):
   - STOP implementation immediately.
   - Report to the user: "Scope has exceeded express criteria (code file touched: `<file>`). Aborting express and switching to full flow."
   - Guide to `/atdd-kit:defining-requirements <issue-number>` to restart properly.
4. Commit with conventional commit format: `docs: <message> (#<N>)`
5. Push: `git push -u origin express/<N>-<slug>`

### atdd-kit Self-Targeting Rule (AC7)

When the target repository **is atdd-kit itself**, the following are mandatory in the same PR — they may NOT be skipped:

- `.claude-plugin/plugin.json` version bump (patch or minor per change type, per DEVELOPMENT.md)
- `CHANGELOG.md` `[Unreleased]` Added/Fixed/Changed entry describing the change

## Step 4: PR Creation

Create the PR with:

```
gh pr create \
  --title "<conventional-title> (#<N>)" \
  --body "$(cat <<'EOF'
## Summary

<one-line description>

## Express Mode

**Applied criterion:** <which OK criterion was matched, with brief rationale>

**Scope confirmation:** Only documentation-grade files were modified. No logic, CI, or dependency changes.

Closes #<N>
EOF
)" \
  --label "express-mode"
```

- The `## Express Mode` section is mandatory and must name the specific OK criterion that justified express (AC6).
- The `express-mode` label is mandatory (AC5). If the label is not found, run `/atdd-kit:setup-github` first.

## Step 5: CI Gate and Human Merge

<HARD-GATE>
Do NOT merge until CI is green. CI bypass (`--admin`, `--merge` before green) is forbidden (AC4).
</HARD-GATE>

Merge is performed by a human — this skill does NOT run `gh pr merge` automatically.

Once CI is green, notify the user: "CI passed. PR #<PR-number> is ready for your review and merge."

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll start without user approval" | AC1: explicit user approval is mandatory before any implementation |
| "This one-liner touches logic — I'll finish and note it" | AC9: scope overflow → abort and report immediately |
| "CI is slow, I'll merge with --admin" | AC4: CI gate is non-negotiable |
| "I'll create the PR without the express-mode label" | AC5: label is mandatory for traceability |
| "I'll skip CHANGELOG / version bump for atdd-kit" | AC7: DEVELOPMENT.md rules apply even in express |
| "The Issue is already in-progress — I'll continue anyway" | AC3: in-progress collision → STOP |
