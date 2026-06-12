---
description: "Explicitly invoke the express fast path for trivial, documentation-grade Issue changes (README edits, typo fixes, gitignore additions, version bumps). Skips PRD/US/plan/AT/review. Requires explicit user approval and CI gate."
---

# /atdd-kit:express — Express Fast Path

## Usage

```
/atdd-kit:express <issue-number>
```

## When to Use

Use express when the Issue is **documentation-grade** with **no functional breakage risk**:

- README or docs edits, typo fixes, inline comment updates
- gitignore additions
- Version bump only (no behavior change)

## When NOT to Use

Do **not** use express when the change involves:

- New features or behavior changes
- Dependency additions
- CI / hooks / scripts changes
- Security impact

When in doubt, use `/atdd-kit:defining-requirements <issue-number>` for the full 6-step ATDD flow.

## Behavior

Delegates to `skills/express/SKILL.md`. The express skill:

1. Validates the Issue number (required; closed/in-progress → STOP)
2. Checks applicability criteria and requires explicit user approval (`<APPROVAL-GATE>`)
3. Creates `express/<N>-<slug>` branch and implements the change
4. Aborts and reports if scope overflows to non-documentation-grade files
5. Opens a PR with `express-mode` label and `## Express Mode` rationale section
6. Waits for CI green; merge is performed by the human

## References

- Full skill: `skills/express/SKILL.md`
- Label setup: `/atdd-kit:setup-github` (creates `express-mode` label)
- Full flow entry: `/atdd-kit:defining-requirements <issue-number>`
