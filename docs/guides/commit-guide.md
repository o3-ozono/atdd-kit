# Commit Guide

> **Loaded by:** rules/atdd-kit.md (referenced), atdd skill

## Commit Granularity

- Commit immediately after each code change, before moving to the next change.
- Keep commits atomic: max 2-3 related files per commit (except bulk renames).
- Do not squash manually within a PR. Merge to main uses `--squash`.

## Work Unit Examples

A single commit should contain one logical work unit:

| Work Unit | What Goes Together |
|-----------|-------------------|
| Story/AC documentation update | Markdown files for the same story |
| Logic + its unit test | Source file + test file |
| UI implementation + utilities | View + helper used only by that view |
| E2E test + test helpers | Test file + shared test utilities |
| CI configuration change | CI config files |

## Anti-patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Squashing the entire PR into 1 commit | Hard to rollback individual changes | Keep atomic commits |
| Committing file-by-file | No context for why the change was made | Group by work unit |
| Separating tests from implementation | Tests and code should move together | Same commit |
| Mixing unrelated changes | Impossible to revert cleanly | Separate commits |

## Prohibited Trailers

Do not add any of the following git trailers:

- `Co-Authored-By`
- `Generated-with`
- `Signed-off-by` (unless required by the project's DCO policy)

These trailers add noise and are not used in this workflow.

## Branch Naming

`<prefix>/<issue-number>-<slug>`

Prefixes: `feat/`, `fix/`, `docs/`, `ci/`, `chore/`, `ops/`, `design/`

## Commit Message Format

Conventional Commits: `<type>: <description> (#<issue>)`

Types: `feat`, `fix`, `docs`, `ci`, `chore`, `refactor`, `test`, `style`
