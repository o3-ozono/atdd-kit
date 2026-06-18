# Templates

Static templates for GitHub issue/PR setup and CI workflow composition. Copied to projects via `/atdd-kit:setup-github` and `/atdd-kit:setup-ci` commands, or synced by `session-start` on plugin updates.

## Structure

### Issue Templates

Located in `issue/en/` and `issue/ja/`.

| Template | Purpose |
|----------|---------|
| `issue/en/development.yml` | Development task Issue template |
| `issue/en/bug-report.yml` | Bug report Issue template |
| `issue/en/documentation.yml` | Documentation task Issue template |
| `issue/en/research.yml` | Research task Issue template |
| `issue/en/refactoring.yml` | Refactoring task Issue template |

#### development.yml field structure (#329 / US-0)

The development template uses an **intent-seed model**: only the three intent fields are `required`; all detail fields are optional (Claude fills them in `defining-requirements` if left blank).

| Field id | Label | required | Notes |
|----------|-------|----------|-------|
| `summary` | 痛み / Problem | **yes** | Describe the problem/pain, not what to implement |
| `outcome` | 望む結果 / Desired outcome | **yes** | What "done" looks like |
| `scope-boundary` | スコープ境界 / Scope boundary | **yes** | Explicit in-scope / out-of-scope |
| `user-story` | ユーザーストーリー | no | Optional; Claude generates if blank |
| `acceptance-criteria` | 受け入れ条件 | no | Optional; Claude generates if blank |
| `subtasks` | サブタスク | no | Optional |
| `completion-criteria` | 完了条件 | no | Optional |

Both `ja/development.yml` and `en/development.yml` maintain the same required/optional structure (enforced by `tests/test_bilingual_templates.bats`).

### PR Templates

| Template | Purpose |
|----------|---------|
| `pr/en/pull_request_template.md` | PR description template |
| `pr/ja/pull_request_template.md` | PR description template (Japanese) |

### CI Base Workflow

| Template | Purpose |
|----------|---------|
| `ci/base.yml` | Platform-agnostic CI workflow (composed with addon CI fragments by `/atdd-kit:setup-ci`) |

## References

- [addons/](../addons/) — Addon CI fragments (e.g., `addons/ios/ci/build-and-test.yml`)
- [commands/setup-github.md](../commands/setup-github.md) — GitHub setup command
- [commands/setup-ci.md](../commands/setup-ci.md) — CI setup command
