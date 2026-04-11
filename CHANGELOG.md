# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.4.0] - 2026-04-12

### Changed
- `workflow-config.yml` simplified to flat `platform` field only — removed `project.name` wrapper (#17)
- session-start confirmation prompt now shows full addon inventory (MCP servers, hooks, deploy files, skills) before asking for confirmation (#17)

### Fixed
- Removed stale `screenshot_script` reference in ship skill (#17)
- Removed stale `review_agents` reference in review-guide (#17)

### Added
- Addon installation inventory section in getting-started.md listing all components each addon installs (#17)

## [1.3.0] - 2026-04-12

### Added
- ideate skill integrated into issue → discover workflow: post-Issue mode, skip option, Context Block handoff (#8)
- issue skill now chains to ideate instead of directly to discover (#8)
- Workflow documentation updated with ideate step in all flow diagrams and skill chain descriptions (#8)

## [1.2.1] - 2026-04-12

### Fixed
- sim-pool-guard.sh: add `build_sim`, `build_run_sim`, `test_sim` to `CLONE_REQUIRED_TOOLS` — previously denied by fail-closed guard (#1)

## [1.2.0] - 2026-04-12

### Added
- autopilot Phase 5: TeamDelete step to remove `autopilot-{issue_number}` team on task completion (#7)
- autopilot Phase 0.9: pre-resolve `TeamDelete` schema via ToolSearch (#7)

## [1.1.0] - 2026-04-11

### Added
- session-start Phase 1-G: auto-configure `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` every session (#2)
- autopilot Prerequisites Check: actionable error message when Agent Teams tools are unavailable (#2)

## [1.0.0] - 2026-04-10

### Added
- `addons/` directory with declarative addon manifest system (`addon.yml`) (#192)
- `addons/ios/` — self-contained iOS addon (scripts, CI fragment, tests, manifest) (#192)
- `agents/` directory with role definitions (po.md, developer.md, qa.md, researcher.md) (#192)
- `templates/ci/base.yml` — platform-agnostic base CI workflow (#192)
- `commands/setup-github.md` — GitHub templates and labels setup command (#192)
- `commands/setup-ci.md` — CI workflow composition command (#192)
- First-time auto-setup in session-start (auto-detects platform from project structure) (#192)

### Changed
- **BREAKING:** Plugin architecture redesigned — init skill abolished, template expansion abolished (#192)
- **BREAKING:** `workflow-config.yml` simplified to `platform` field only (removed: language, build, paths, autonomous_processes, skill_adapters, environment, design) (#192)
- **BREAKING:** LLM-facing files are English only — all SKILL.ja.md and docs/*.ja.md removed (#192)
- `scripts/ios/` moved to `addons/ios/scripts/` (#192)
- `tests/test_sim_*.bats` moved to `addons/ios/tests/` (#192)
- `commands/autopilot.md` — reads agent definitions from `agents/` instead of `autonomous_processes` in workflow-config.yml (#192)
- `skills/session-start/SKILL.md` — addon-aware file sync replaces hardcoded sync table (#192)
- `rules/atdd-kit.md` — language resolution section replaced with addons section (#192)

### Removed
- `skills/init/` — init skill abolished; replaced by session-start auto-setup (#192)
- `templates/*.tmpl` — pseudo-Handlebars template expansion abolished (#192)
- `docs/language-resolution.md`, `docs/i18n-strategy.md` — i18n simplified (#192)
- All `SKILL.ja.md` files (12 files) — English only for LLM-facing content (#192)
- All `docs/*.ja.md` files (7 files) — English only for LLM-facing docs (#192)
- `autonomous_processes` and `skill_adapters` from workflow-config.yml — moved to agents/ (#192)

