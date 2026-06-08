# Scripts

Utility scripts used by commands, skills, and CI. All scripts are pure bash (or Node.js where necessary) with zero external dependencies.

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| [check-plugin-version.sh](check-plugin-version.sh) | Detects plugin version changes for update notifications | Called by `session-start` skill |
| [measure-footprint.sh](measure-footprint.sh) | Static context/token footprint measurement and regression detection | `measure-footprint.sh measure <name>` / `--check` / `--update` |
| [start-session.sh](start-session.sh) | Starts Claude Code session | Run manually to start a session |
| [pr-screenshot-table.sh](pr-screenshot-table.sh) | Adds before/after screenshot comparison tables to PR descriptions | Called during PR creation |
| [upload-image-to-github.mjs](upload-image-to-github.mjs) | Uploads images to GitHub via PR comment and retrieves URLs | Called by `pr-screenshot-table.sh` |
| [measure-token-reduction.sh](measure-token-reduction.sh) | Measures token reduction between before/after log files using byte-count proxy | Run manually for AC4 verification |
| [impact_map.sh](impact_map.sh) | Maps git diff to affected tests via path rules and `@covers` metadata | `impact_map.sh --base <ref> --layer {skill-e2e\|BATS}` |
| [lint_skill_descriptions.sh](lint_skill_descriptions.sh) | Scans `skills/*/SKILL.md` for description anti-patterns (step-chain, length > 200, dash-separator lists). WARN-only, exit 0. | `scripts/lint_skill_descriptions.sh` |
| [check-issue-collision.sh](check-issue-collision.sh) | Detects parallel work on the same Issue across git worktrees (in-progress writes under `docs/issues/<N>/`). Used by `skill-gate`. Exit 1 on collision. | `scripts/check-issue-collision.sh --issue <N>` |
| [ci/skill-e2e-guard.sh](ci/skill-e2e-guard.sh) | Subscription-only Skill E2E CI guards (billing-redirect env blocklist + main-ref trust boundary); single-source, behaviorally tested. | `ci/skill-e2e-guard.sh {billing-env\|main-ref <ref>}` |

iOS-specific scripts are in `addons/ios/scripts/`. See [addons/ios/README.md](../addons/ios/README.md).

## Prerequisites

- BATS v1.5.0+ (for `--separate-stderr` and `bats_require_minimum_version`)

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Zero dependencies policy
