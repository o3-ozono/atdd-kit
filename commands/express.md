---
description: "Fast path for trivial, low-risk changes. Bypasses discover/plan/review. Requires Issue number and explicit user approval."
---

# express — Fast Path for Trivial Changes

Invocation: `/atdd-kit:express <issue-number>`

Delegates to `skills/express/SKILL.md`.

## When to Use

Use this command for **trivial, low-risk changes** where the full discover → plan → ATDD → review chain is unnecessary overhead:

- Typo fixes in documentation
- Adding a `.gitignore` entry
- One-line inline comment additions
- Broken hyperlink corrections

See `docs/guides/express-mode.md` for the full OK/NG applicability criteria.

## When NOT to Use

Do not use this command for:

- New features or behavior changes
- API or interface changes
- Changes with security implications
- Any change requiring design discussion

Use `/atdd-kit:autopilot <issue-number>` for those cases instead.

## What This Command Does

1. Validates the issue number argument (missing → STOP)
2. Fetches issue details with `gh issue view`
3. Guards against closed issues and in-progress locks
4. Presents Express OK/NG criteria and requests explicit user approval + rationale
5. If approved: implements the change, creates a PR with `express-mode` label and `## Express Mode` section
6. Waits for CI to pass (mandatory gate — cannot be skipped)
7. Squash-merges: `gh pr merge --squash`

## Governance Maintained

Express mode does **not** bypass:
- Issue-driven development (Issue number required)
- CI gate (PR checks must pass)
- Version bump in `.claude-plugin/plugin.json`
- `CHANGELOG.md` entry

## Usage

```
/atdd-kit:express 42
```
