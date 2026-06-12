# Definition of Done (DoD)

> **Loaded by:** running-atdd-cycle (Step 4), reviewing-deliverables (Step 5), merging-and-deploying (Step 6)

An Issue is **Done** when every criterion below is met. The merging-and-deploying skill (Step 6) checks DoD before marking an Issue closed.

## DoD Criteria

### AC Gate

| # | Criterion | How to Verify |
|---|-----------|---------------|
| D1 | **All ACs implemented** — every Given/When/Then AC has passing tests | running-atdd-cycle evidence report |
| D2 | **Story Test (Q2) passes** — outer-loop integration/E2E test per AC | CI green on Story Tests |
| D3 | **Unit Tests (Q1) pass** — inner-loop unit tests for all extracted logic | CI green on unit tests |
| D4 | **No weakened tests** — no tests mocked away or conditioned to always pass | PR review check |

For AC-to-test-layer mapping rules, see [test-mapping.md](./test-mapping.md). test-mapping.md is the authority for what constitutes Q1/Q2 coverage.

### CI Gate

| # | Criterion | How to Verify |
|---|-----------|---------------|
| D5 | **CI all green** — all tests pass on the PR branch | GitHub Actions status |
| D6 | **No linter errors** — static analysis passes | CI linter step |
| D7 | **BATS suite green** — if a skill changed, the relevant `tests/*.bats` cover the change and pass | `bats tests/` output |

### PR Gate

| # | Criterion | How to Verify |
|---|-----------|---------------|
| D8 | **PR review approved** — reviewing-deliverables (Step 5) の動的レビューパネルが PASS を出力、または人間レビュアーの承認 | GitHub PR review status |
| D9 | **No open review comments** — all threads resolved | GitHub PR threads |
| D10 | **Issue linked in PR body** — `Closes #NNN` in PR description | PR body check |

### Documentation Gate

| # | Criterion | How to Verify |
|---|-----------|---------------|
| D11 | **CHANGELOG.md updated** — entry added in the correct section | `CHANGELOG.md` diff |
| D12 | **Version bumped** — `.claude-plugin/plugin.json` version incremented (for feature/skill PRs) | `plugin.json` diff |
| D13 | **Spec file updated** — `docs/specs/<slug>.md` status is `implemented` | spec file frontmatter |

### Skill Change Additional Conditions

When the PR modifies a `skills/*/SKILL.md` file, these additional criteria apply:

| # | Criterion | How to Verify |
|---|-----------|---------------|
| DS1 | **BATS coverage present** — the change is covered by a `tests/*.bats` case that asserts the new/changed skill behavior | `bats tests/` includes the relevant test |
| DS2 | **No weakened skill tests** — no `@test` block deleted or conditioned to always pass to accommodate the change | PR diff review |
| DS3 | **skills/README.md updated** if skill added or removed | README diff |

## Increment = Done Issue

An Increment is complete when:
1. All DoD criteria above are met.
2. The PR is merged to `main`.
3. The Issue is closed.

A merged PR without a closed Issue is not a complete Increment — it may be a partial contribution.

## Relationship to Scrumban Labels

| Label | DoD Relationship |
|-------|-----------------|
| `implementing` | running-atdd-cycle in progress; DoD not yet met |
| `ready-for-PR-review` | AC gate + CI gate met; awaiting PR review |
| `needs-pr-revision` | PR gate failed; revision needed |
| (Issue closed) | Full DoD confirmed; merging-and-deploying complete |

See [scrumban.md](./scrumban.md) for the full label correspondence table.

## References

- [test-mapping.md](./test-mapping.md) — AC-to-test-layer mapping (Q1/Q2 authority)
- [us-ac-format.md](./us-ac-format.md) — AC spec format and status transitions
- [scrumban.md](./scrumban.md) — Full methodology context and Increment definition
- [definition-of-ready.md](./definition-of-ready.md) — DoR (entry condition)
- [atdd-guide.md](./atdd-guide.md) — Double-loop TDD rules
