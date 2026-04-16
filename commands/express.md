---
description: "Fast path for trivial, low-risk changes. Bypasses discover/plan/review. Requires Issue number and explicit user approval."
---

# express — Fast Path for Trivial Changes

`/atdd-kit:express <issue-number>` — delegates to `skills/express/SKILL.md`.

## When to Use

Trivial, low-risk changes where full discover → plan → ATDD → review is unnecessary:
- Typo fixes in documentation
- Adding a `.gitignore` entry
- One-line comment additions
- Broken hyperlink corrections

See `docs/guides/express-mode.md` for OK/NG criteria.

## When NOT to Use

- New features or behavior changes
- API or interface changes
- Security implications
- Changes requiring design discussion

Use `/atdd-kit:autopilot <issue-number>` instead.

## What This Command Does

1. Validate issue number (missing → STOP)
2. `gh issue view` — guard against closed issues and in-progress locks
3. Present OK/NG criteria, request explicit approval + rationale
4. Implement change, create PR with `express-mode` label and `## Express Mode` section
5. Wait for CI (mandatory, cannot skip)
6. `gh pr merge --squash`

## Governance Maintained

Express does **not** bypass:
- Issue-driven development (number required)
- CI gate
- Version bump in `.claude-plugin/plugin.json`
- `CHANGELOG.md` entry
