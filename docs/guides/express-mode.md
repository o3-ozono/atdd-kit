# Express Mode Guide

Express mode (`/atdd-kit:express <issue>`) is a fast path for low-risk, trivial changes that do not require the full discover → plan → ATDD → review chain. It maintains Issue-driven development, CI gates, and DEVELOPMENT.md mandatory processes.

## When to Use Express Mode

Express mode is appropriate only for changes where:
- The change is **self-evident** — no design discussion needed
- The scope is **extremely narrow** — one file or a few lines
- **No behavior changes** are introduced
- **No API changes** or new dependencies are added
- The risk of unintended side effects is **negligible**

## OK Examples

Changes that are appropriate for Express mode:

- Adding an entry to `.gitignore` (e.g., ignoring a runtime state file)
- Fixing a typo in documentation or a comment
- Adding a one-line inline comment to clarify existing code
- Bumping a version number alone (when no other changes are needed)
- Fixing a broken hyperlink in documentation
- Correcting a formatting error in a Markdown table

## NG Examples

Changes that are **NOT** appropriate for Express mode and require the full workflow:

- Adding a new feature or new behavior to a skill or command
- Changing function signatures, API contracts, or plugin interfaces
- Adding new dependencies (npm packages, external services, etc.)
- Changes with security implications (authentication, authorization, credential handling)
- Modifying CI/CD pipeline definitions
- Refactoring that touches multiple files or changes execution paths
- Any change where reasonable people might disagree on the approach

## Governance

Express mode does **not** bypass:

| Requirement | Status |
|-------------|--------|
| Issue-driven development (Issue number required) | Maintained |
| CI gate (PR checks must pass before merge) | Maintained |
| Version bump in `.claude-plugin/plugin.json` | Maintained |
| `CHANGELOG.md` entry | Maintained |
| `express-mode` label on PR | Required for traceability |
| Rationale recorded in PR body | Required for audit trail |

Express mode **does** bypass:
- discover (requirements exploration)
- plan (test strategy and implementation plan)
- Three Amigos review
- PR reviewer cycle (no `ready-for-PR-review` label; auto-merge after CI passes)

## Escalation

If, during Express mode implementation, you discover the change is more complex than initially assessed (e.g., a typo fix requires refactoring an API), you must:

1. STOP the Express mode flow
2. Report the complexity increase to the user
3. Restart using the full workflow: `/atdd-kit:autopilot <issue-number>`

Do not continue in Express mode when the OK criteria are no longer met.
