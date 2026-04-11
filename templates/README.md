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
| `issue/en/investigation.yml` | Investigation task Issue template |
| `issue/en/refactoring.yml` | Refactoring task Issue template |

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
