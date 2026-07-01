# Scripts

Utility scripts used by commands, skills, and CI. All scripts are pure bash (or Node.js where necessary) with zero external dependencies.

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| [check-plugin-version.sh](check-plugin-version.sh) | Detects plugin version changes and session state for update notifications. Outputs one of: FIRST_RUN / NO_UPDATE / UPDATED (5-line format with VERSIONS/BREAKING counts) / RESTART_REQUIRED (installed version newer than loaded — restart needed) / STALE_SESSION (loaded version older than cached marker — stale session detected). All detection is local-file-only with no network access. | Called by `session-start` skill |
| [measure-footprint.sh](measure-footprint.sh) | Static context/token footprint measurement and regression detection | `measure-footprint.sh measure <name>` / `--check` / `--update` |
| [start-session.sh](start-session.sh) | Starts Claude Code session | Run manually to start a session |
| [pr-screenshot-table.sh](pr-screenshot-table.sh) | Adds before/after screenshot comparison tables to PR descriptions | Called during PR creation |
| [upload-image-to-github.mjs](upload-image-to-github.mjs) | Uploads images to GitHub via PR comment and retrieves URLs | Called by `pr-screenshot-table.sh` |
| [measure-token-reduction.sh](measure-token-reduction.sh) | Measures token reduction between before/after log files using byte-count proxy | Run manually for AC4 verification |
| [impact_map.sh](impact_map.sh) | Maps git diff to affected tests via path rules and `@covers` metadata. Supports `--platform {web\|ios\|other}` for multi-platform adapter selection (other=bats/@covers, web=jest/vitest, ios=XCTest). | `impact_map.sh --platform <p> --base <ref> --layer {skill-e2e\|BATS}` |
| [lint_skill_descriptions.sh](lint_skill_descriptions.sh) | Scans `skills/*/SKILL.md` for description anti-patterns (step-chain, length > 200, dash-separator lists). WARN-only, exit 0. | `scripts/lint_skill_descriptions.sh` |
| [check-issue-collision.sh](check-issue-collision.sh) | Detects parallel work on the same Issue across git worktrees (in-progress writes under `docs/issues/<N>/`). Used by `skill-gate`. Exit 1 on collision. | `scripts/check-issue-collision.sh --issue <N>` |
| [ci/skill-e2e-guard.sh](ci/skill-e2e-guard.sh) | Subscription-only Skill E2E CI guards (billing-redirect env blocklist + main-ref trust boundary); single-source, behaviorally tested. | `ci/skill-e2e-guard.sh {billing-env\|main-ref <ref>}` |
| [run-tests.sh](run-tests.sh) | Zero-dependency parallel BATS runner with weighted file sharding. Delegates target-file selection to `impact_map.sh`. | `run-tests.sh --all [--jobs <n>]` / `run-tests.sh --impact --base <ref> [--jobs <n>]` |
| [retrospective.sh](retrospective.sh) | Auto-generates a flow retrospective report after Issue completion: dialogue volume (turns), token cost, normalized ratio, friction points, and skill-fix candidates. Zero LLM invocations; zero blocking prompts; CS-1 lightweight. Called by `merging-and-deploying` skill as the sole retrospective entry point; express Issues skip structurally. | `retrospective.sh --issue <N> [--pr <PR>] [--dry-run] [--json-output]` |
| [session-lease-scan.sh](session-lease-scan.sh) | Scans `BRANCH_LEASE_DIR` (default `/tmp/claude-branch-leases`) for branches with fresh leases (within `BRANCH_LEASE_TTL_LOCAL`, default 7200s). Outputs one branch name per line. Used by `session-start` skill to detect branches held by another session (Draft-independent, read-only). | Called by `session-start` skill Phase 1-B |
| [bats_runner.sh](bats_runner.sh) | Impact-scoped BATS runner. `--all` runs the full BATS suite; `--impact --base <ref>` delegates to `impact_map.sh --layer BATS` to run only affected files. Underlies `run-tests.sh`. | `bats_runner.sh --all [--repo <path>]` / `bats_runner.sh --impact --base <ref> [--repo <path>]` |
| [check_bats_covers.sh](check_bats_covers.sh) | Validates that every `tests/*.bats` (and `addons/*/tests/*.bats`) file declares a `# @covers:` annotation, so `impact_map.sh`'s reverse lookup (`--layer BATS`) can find it. | `check_bats_covers.sh [<file> ...]` (no args: scans the default tree) |
| [run-skill-e2e.sh](run-skill-e2e.sh) | Skill E2E Test runner with path-based impact mapping: maps changed `skills/<X>/` files to `tests/e2e/<X>.bats`, `rules/`/`templates/`/`docs/methodology/` to all e2e, and `lib/`/`scripts/` changes to any skill whose SKILL.md cites them. | `run-skill-e2e.sh --changed-files <f1>[,<f2>...] [--dry-run]` / `run-skill-e2e.sh --all [--dry-run]` |
| [test-skills-headless.sh](test-skills-headless.sh) | Headless skill-chain integration test runner (live `claude -p` invocation or replay against a captured transcript). | `test-skills-headless.sh <scenario.json>` / `test-skills-headless.sh --replay <transcript> <scenario.json>` |
| [check-required-labels.sh](check-required-labels.sh) | Pre-flight check: detects missing GitHub workflow labels against the canonical set parsed from `commands/setup-github.md`, and (with `--create`) remediates via idempotent `gh label create --force`. Notify-only — never error-exits; gracefully skips when `gh` is absent/unauthenticated. | Called by `autopilot` / `full-autopilot` startup; `scripts/check-required-labels.sh [--create]` |

**`--layer` / `--platform` constraint:** `impact_map.sh --layer` accepts `skill-e2e` or `BATS`.
atdd-kit's own tooling (`bats_runner.sh`, `run-tests.sh`) always drives `impact_map.sh` with
`--layer BATS` under the default `--platform other` adapter (bats/`@covers`-based selection) —
`--layer skill-e2e` is not meaningful for atdd-kit's own BATS suite. Consumer projects using the
Web/iOS addons instead drive `impact_map.sh --platform {web|ios} --layer skill-e2e`, where the
returned identifiers are jest/vitest/playwright group names (web) or XCTest/XCUITest target names
(ios) resolved from `config/impact_rules.yml`, not `.bats` file paths. Do not mix `--layer BATS`
with `--platform web`/`--platform ios`, or vice versa with `--layer skill-e2e` under `--platform
other` — each platform's `impact_rules.yml` is shaped for one layer only.

iOS-specific scripts are in `addons/ios/scripts/`. See [addons/ios/README.md](../addons/ios/README.md).

## Prerequisites

- BATS v1.5.0+ (for `--separate-stderr` and `bats_require_minimum_version`)

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Zero dependencies policy
