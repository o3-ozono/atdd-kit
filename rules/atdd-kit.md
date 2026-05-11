# atdd-kit Rules

**Violating the letter of the rules is violating the spirit.** No rationalization.

## Iron Laws (never violate)
1. No code edits without an Issue.
2. No implementation without approved ACs.
3. No completion claims without fresh verification evidence.
4. atdd / verify / bug must load `docs/specs/<slug>.md` via `lib/spec_check.sh` before implementation or AC judgement.

## Instruction Priority
1. User's explicit instructions (CLAUDE.md, direct requests) -- highest
2. atdd-kit skills -- override default behavior / 3. Default system prompt -- lowest

## Addons
Platform-specific addons are in `${CLAUDE_PLUGIN_ROOT}/addons/`. Each addon has `addon.yml` declaring MCP servers, hooks, deploy files, and CI fragments. See `${CLAUDE_PLUGIN_ROOT}/addons/README.md`.

## Workflow (v1.0 6-step, migration in progress)
| Step | Skill | Deliverable in `docs/issues/<NNN>/` |
|------|-------|-------------------------------------|
| 1. Discovery & Definition | `defining-requirements` | `prd.md` |
| 2. User Stories | `extracting-user-stories` | `user-stories.md` |
| 3. Plan + AT | `writing-plan-and-tests` | `plan.md`, `acceptance-tests.md` |
| 4. ATDD | `running-atdd-cycle` | `tests/acceptance/AT-*.*` (draft → green) |
| 5. Review | `reviewing-deliverables` | review notes |
| 6. Merge + Deploy | `merging-and-deploying` | merged PR + post-deploy regression |

- Exclusive lock: do not start work on an Issue with `in-progress` label.
- Test-first, always. 1 PR = 1 thing.

## Commits
- Conventional Commits: `<type>: <description> (#<issue>)`. Commit after each change.
- Tests + implementation together. Only related files (max 2-3).
- Branch: `<prefix>/<issue-number>-<slug>` (`feat/`, `fix/`, `docs/`, `ci/`, `chore/`, `ops/`, `design/`)
- Open Draft PR on first commit/push to the branch (commit moment = Draft PR moment).

## PRs
Start with `Closes #<issue-number>`. Merge with `--squash`. Add matching `type:` label.
1 Issue = 1 worktree = 1 Draft PR.

## Label Flow
- Issue: (no label) -> `in-progress` -> `ready-for-plan-review` -> `ready-to-go` -> `in-progress`
- PR: `ready-for-PR-review` -> merge (or `needs-pr-revision` loop)

## Docs & Errors
Every change includes doc updates (`${CLAUDE_PLUGIN_ROOT}/docs/guides/doc-sync-checklist.md`). Investigate root cause first -- no workarounds without understanding.

## Guides
`${CLAUDE_PLUGIN_ROOT}/docs/guides/commit-guide.md` | `${CLAUDE_PLUGIN_ROOT}/docs/workflow/workflow-detail.md` | `${CLAUDE_PLUGIN_ROOT}/docs/guides/review-guide.md` | Issue Ready: `atdd-kit:discover`

When EN/JA variants exist (`*.ja.md`, `*-ja.yml`), read EN only. Read JA only when editing or syncing.
