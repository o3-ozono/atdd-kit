# atdd-kit Development Instructions

When working on this repository (atdd-kit plugin itself), you **must** read `DEVELOPMENT.md` at the start of every session. It contains non-negotiable rules for versioning, i18n, and architecture.

## Workflow (v1.0 migration in progress)

Work follows the 6-step ATDD flow. Each Issue gets its own directory under `docs/issues/<NNN>/`.

| Step | Skill | Deliverable |
|------|-------|-------------|
| 1. Discovery & Definition | `defining-requirements` | `docs/issues/<NNN>/prd.md` |
| 2. User Stories | `extracting-user-stories` | `docs/issues/<NNN>/user-stories.md` |
| 3. Plan + AT | `writing-plan-and-tests` | `docs/issues/<NNN>/plan.md`, `docs/issues/<NNN>/acceptance-tests.md` |
| 4. ATDD | `running-atdd-cycle` | `tests/acceptance/AT-*.*` (draft → green) |
| 5. Review | `reviewing-deliverables` | review notes |
| 6. Merge + Deploy | `merging-and-deploying` | merged PR + post-deploy regression |

Discipline: 1 Issue = 1 worktree = 1 Draft PR. Open the Draft PR on the first commit/push.

## Key References

- `DEVELOPMENT.md` — Mandatory rules (versioning, i18n, language policy, release process)
- `CHANGELOG.md` — Keep a Changelog format, must be updated with every feature PR
- `rules/atdd-kit.md` — Always-loaded rules; canonical statement of the 6-step Workflow table.
- `docs/issues/<NNN>/` — Per-Issue artifacts. Example: `docs/issues/179-atdd-kit-v1-redesign/prd.md`.
