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

iOS-specific scripts are in `addons/ios/scripts/`. See [addons/ios/README.md](../addons/ios/README.md).

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Zero dependencies policy
