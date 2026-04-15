# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.14.1] - 2026-04-15

### Changed
- `.gitignore`: Added `.claude/cb-state.json` to prevent accidentally committing circuit breaker runtime state files. (#92)

## [1.14.0] - 2026-04-15

### Added
- `lib/circuit_breaker.sh`: Three-state circuit breaker (CLOSED/HALF\_OPEN/OPEN) for autopilot infinite-loop prevention. Tracks `no_progress` (threshold 3) and repeated error fingerprints (threshold 5 consecutive). State persisted to `.claude/cb-state.json` (cwd-relative, worktree-scoped). No external dependencies (pure bash). (#56)
- `lib/README.md`: Directory README for the new `lib/` directory. (#56)
- `docs/guides/circuit-breaker.md`: Full specification — states, thresholds, subcommand reference, trigger events, fingerprint convention, and reset procedure. (#56)
- `tests/test_circuit_breaker.bats`: Unit tests for AC1–AC8 (37 cases). (#56)
- `tests/test_autopilot_cb_integration.bats`: Integration tests verifying CB check insertion in `commands/autopilot.md` at all 3 iteration entry points (AC9, 8 cases). (#56)
- `commands/autopilot.md`: Circuit Breaker Check blockquotes at Plan Review Round, Phase 3, and Phase 4 entry points. Circuit Breaker Integration section with trigger event table and fingerprint convention. (#56)
- `hooks/bash-output-normalizer.sh`: New PostToolUse hook that normalizes Bash tool output — JSON minify, 3+ consecutive blank line collapse to 2, trailing whitespace removal per line. Reduces token consumption from gh/Bash tool outputs. (#85)
- `hooks/hooks.json`: PostToolUse section added with Bash-only matcher and 10s timeout, distributing `bash-output-normalizer.sh` via plugin mechanism. (#85)
- `scripts/measure-token-reduction.sh`: New script for measuring token reduction between before/after log files using byte-count proxy. (#85)
- `fixtures/token-reduction/`: Fixed mock log fixtures for reproducible AC4b measurement (baseline/ and after/ directories). (#85)
- `docs/guides/token-reduction-results.md`: Token reduction measurement results: AC1 25.8%, AC2 75.3%, AC3 23.9% — all exceed baseline targets. (#85)

### Changed
- `skills/session-start/SKILL.md`: Phase 1-B `gh pr view` call removes unused `mergeStateStatus` field, reducing fetched data by ~3%. (#85)
- `commands/autopilot.md`: Phase 5 merges separate `--json statusCheckRollup` and `--json mergeable` calls into one `--json statusCheckRollup,mergeable` call. Phase 2, Plan Review Round, and Phase 3 SendMessage/spawn instructions updated to use reference-based context (Issue number + comment reference) instead of full-text injection. (#85)

## [1.13.2] - 2026-04-15

### Added
- `docs/specs/` directory with `README.md` and `TEMPLATE.md` for persisting User Story + Acceptance Criteria spec files beyond Issue closure. (#66)
- `docs/methodology/us-ac-format.md`: US/AC spec file format definition (frontmatter schema, status transitions, filename convention, TBD persona rule, rename run-book). (#66)
- `docs/specs/us-ac-format.md`: self-referencing sample spec for the format introduced in #66. (#66)
- `tests/test_us_ac_format.bats`: structural bats tests for docs/specs/ and format compliance. (#66)

## [1.13.1] - 2026-04-15

### Fixed
- `commands/autopilot.md`: Phase 1 Step 4「PO derives draft ACs through Stakeholder dialogue」を削除し、`SKILL_STATUS: COMPLETE` 受信時の即時 AC Review Round 遷移と中間ユーザーメッセージ禁止を明示。autopilot が discover → AC Review Round 間で不要な停止をするバグを修正。(#83)

## [1.13.0] - 2026-04-15

### Changed
- `scripts/check-plugin-version.sh`: UPDATED output changed from raw CHANGELOG diff to 5-line structured summary (`UPDATED`, `<old>`, `<new>`, `VERSIONS: <N>`, `BREAKING: <M>`). Eliminates large CHANGELOG dumps from session-start context. (#75)
- `skills/session-start/SKILL.md`: Phase 1-E updated to parse VERSIONS/BREAKING counts from new 5-line output. Phase 3 report template updated to show concise `v<old> → v<new> (N versions, M breaking changes). See CHANGELOG.md for details.` format. (#75)
- `tests/test_check_plugin_version.bats`: AC1-AC5 tests added for structured summary format; legacy CHANGELOG diff inclusion test removed. (#75)
- `tests/test_session_start_version.bats`: AC6 tests added verifying SKILL.md Phase 1-E and Phase 3 reflect new output protocol. (#75)

## [1.12.1] - 2026-04-15

### Added
- `rules/atdd-kit.md`: EN/JAバリアント存在時のEN優先読み取りルールを追加。`*.ja.md`/`*-ja.yml`はLLMが編集・同期時のみ読む。(#77)
- `skills/issue/SKILL.md`, `skills/bug/SKILL.md`: ENテンプレートのみを使用する旨と`-ja.yml`バリアントは人間のGitHub Web UI用である旨の注記を追加。(#77)
- `tests/test_i18n_language_resolution.bats`: EN優先読み取りルールの存在を検証するテストを追加。(#77)
- `tests/test_bilingual_templates.bats`: SKILL.mdのEN-only注記と-ja.yml除外を検証するテストを追加。(#77)

## [1.12.0] - 2026-04-15

### Added
- `docs/methodology/test-mapping.md`: new AC-to-test-layer mapping guide for the plan skill. Documents 1 AC = 1 Outer Loop cycle rule, Testing Quadrants (Q1-Q4), Double-Loop TDD Mermaid diagram, AC wording → test layer decision table, and usage guide for plan Step 3. (#67)

### Changed
- `docs/methodology/atdd-guide.md`: Double-Loop TDD section updated with cross-reference to test-mapping.md and inline AC correspondence annotation. (#67)
- `docs/README.md`: test-mapping.md entry added to methodology/ table. (#67)

## [1.13.0] - 2026-04-15

### Added
- `docs/methodology/persona-guide.md`: Comprehensive persona guide covering Cooper's Goal-Directed Design, Elastic User Problem, persona format (Name, Role, Goals, Context, Quote), Primary/Secondary/Negative types, creation process, anti-patterns, and discover skill reference method. (#65)
- `docs/personas/TEMPLATE.md`: Blank persona template matching the format defined in persona-guide.md. (#65)
- `docs/personas/README.md`: Directory index with purpose, template usage, and one-file-per-persona convention. (#65)
- `tests/test_persona_guide.bats`: Static verification tests for all persona guide ACs (AC1-AC7). (#65)

### Changed
- `docs/README.md`: Added `personas/` category section following existing format. (#65)

### Removed
- `agents/po.md` deleted — the PO agent definition was a redundant metadata shell (1-line system_prompt + tools list). main Claude already fulfills the PO role directly in autopilot, so the separate agent definition was misleading. All references updated to reflect main Claude as the orchestrator. (#45)

### Changed (#45)
- `commands/autopilot.md`: frontmatter description updated from "PO-led" to "Autopilot end-to-end workflow"; po.md file path references removed from Prerequisites, Phase 0.9, and Session Initialization; "main Claude acts as PO directly" added.
- `agents/developer.md`: "report to PO" → "report to team-lead (the autopilot orchestrator — main Claude)"
- `agents/qa.md`: "Escalate to PO" → "Escalate to team-lead (team-lead is the autopilot orchestrator — main Claude)"
- `agents/README.md`: po.md row removed from Available Agents table; Via Autopilot and Standalone sections updated.
- `README.md`, `README.ja.md`: "PO agent" → "main Claude as orchestrator"; "Seven agents" → "Six agents"; Agent Composition Table PO column → "main Claude"; Mermaid diagram PO node updated.
- `docs/workflow-detail.md`, `docs/getting-started.md`, `commands/README.md`, `skills/README.md`: PO references updated to reflect main Claude as orchestrator.

### Added
- `hooks/main-branch-guard.sh`: PreToolUse hook that denies Edit/Write/MultiEdit/NotebookEdit on `main`/`master` branches. Distributed via `hooks/hooks.json` so all atdd-kit projects receive it automatically. Fail-safe: non-git directories, detached HEAD, and git unavailability all pass through with `{}`. (#38)

### Removed (BREAKING CHANGE)
- **Decision Trail / Decision Record system fully abolished (#42).** The `docs/decisions/` directory, every auto-generated agent deliverable file (`ac-review-*.md`, `impl-strategy-*.md`, `plan-review-*.md`, `test-strategy-*.md`, `pr-review-reviewer-*.md`, `research-*.md`, `draft-acs.md`, `unified-plan.md`, etc.), and the `skills/record` skill are removed. This is a **reversal of #13 / #25** — the `record` skill introduced in 1.6.0 and the `ship` Step 11 chain-to-record are no longer part of the workflow.
- `skills/record/SKILL.md` deleted
- `skills/ship/SKILL.md`: Step 11 (Chain to Decision Record) removed
- `commands/autopilot.md`: Phase 0.9 `mkdir -p docs/decisions` removed; all agent `write results to docs/decisions/...` directives replaced with `SendMessage` reply / Issue-PR comment channels
- `docs/workflow-detail.md`: Decision Trail section replaced with Output Channels section
- `docs/README.md`: `decisions/` subdirectory entry removed
- Tests: `tests/test_decision_record.bats` deleted; Decision Trail assertions (#165-AC3, #165-AC4, #180-AC2) removed from `tests/test_autopilot_agent_teams_setup.bats`

### Changed (#50)
- `commands/autopilot.md`: translate all Japanese content to English (20 occurrences) — DEVELOPMENT.md language policy compliance (#50)
- `skills/plan/SKILL.md`: translate all Japanese content to English (6 occurrences) — DEVELOPMENT.md language policy compliance (#50)
- `skills/discover/SKILL.md`: translate Japanese example to English (1 occurrence) — DEVELOPMENT.md language policy compliance (#50)
- `skills/skill-gate/SKILL.md`: translate Japanese keyword examples to English (2 occurrences) — DEVELOPMENT.md language policy compliance (#50)
- `skills/bug/SKILL.md`: translate Japanese trigger keywords to English (1 occurrence) — DEVELOPMENT.md language policy compliance (#50)

### Changed (#42)
- `skills/discover` and `skills/plan`: `Discussion Summary` section is now described as "remains in the Issue comment as the permanent record" rather than "consumed by the record skill"
- `skills/README.md`: workflow chain diagram updated to end at `ship` (no trailing `record`)
- autopilot / workflow-detail: explicit **Output Channels** rule added — inter-agent handoffs flow via `SendMessage`, human-facing work logs flow via Issue / PR comments. Writing agent deliverables to `docs/decisions/` or any other repository path is prohibited. Curated knowledge graduates into existing docs only by explicit human decision.

### Rationale
The original Issue #42 was a one-off bug ("Phase 4 Reviewer Decision Trail file not committed"), but investigation showed the underlying mechanism was over-engineered: auto-generated files were not actually being read, the same information already existed in Issue / PR comments, and the write / commit responsibility was unclear across roles. Removing the mechanism eliminates the bug class entirely and aligns the workflow with where discussion already happens.

## [1.11.1] - 2026-04-15

### Removed
- `agents/po.md` deleted — the PO agent definition was a redundant metadata shell (1-line system_prompt + tools list). main Claude already fulfills the PO role directly in autopilot. (#45)

### Changed
- `commands/autopilot.md`: frontmatter description updated; po.md file path references removed from Prerequisites, Phase 0.9, and Session Initialization. (#45)
- `agents/developer.md`: "report to PO" → "report to team-lead (the autopilot orchestrator — main Claude)". (#45)
- `agents/qa.md`: "Escalate to PO" → "Escalate to team-lead (team-lead is the autopilot orchestrator — main Claude)". (#45)
- `agents/README.md`, `README.md`, `README.ja.md`, `docs/workflow-detail.md`, `docs/getting-started.md`, `commands/README.md`, `skills/README.md`: PO references updated; "Seven agents" → "Six agents"; Agent Composition Table PO → "main Claude". (#45)

## [1.11.0] - 2026-04-15

### Added
- `commands/autopilot.md`: Plan Review Round step 6 — clear/continue stop-point fires after `ready-to-go` label is set in the same session. Presents `AskUserQuestion` 2-option prompt (clear and end / continue to Phase 3). Clear selection prints resume guidance (`/atdd-kit:autopilot <N>`) and terminates autopilot. Continue proceeds to Phase 3 unchanged. Mid-phase resume (new session, `ready-to-go` already set) bypasses stop-point via Phase 0.5 determination. Other/unclassifiable response follows Autonomy Rules failure mode — report and STOP. (#54)
- `agents/po.md`: Added `AskUserQuestion` to PO `tools:` list to support the Plan approval stop-point. (#54)

## [1.10.0] - 2026-04-13

### Added
- docs: `skill-authoring-guide.md` — Dialogue UX design principles for skill authors (AskUserQuestion constraints, Recommended pattern, closed question guidelines) (#35)
- tests: `test_question_design_migration.bats` with 40 tests covering AC1-AC7 (#35)
- ideate: evals `baseline.json` with pass_rate 1.0 baseline for 4 eval scenarios (#35)
- issue: evals `baseline.json` with pass_rate 1.0 baseline for 5 eval scenarios (#35)
- bug: evals `baseline.json` with pass_rate 1.0 baseline for 2 eval scenarios (#35)

### Changed
- ideate: Step 0 (Brainstorm?), Step 2 approach selection, Step 3 approval — converted from inline text choices to AskUserQuestion + Recommended pattern (#35)
- issue: Priority confirmation — converted from inline text to AskUserQuestion + Recommended pattern (#35)
- bug: Fix Proposal approval — converted from inline arrow prompt to AskUserQuestion + Recommended pattern (#35)
- discover: Approach selection, DoD confirmation, User Story confirmation, AC approval, Root Cause confirmation, Docs DoD approval — converted to AskUserQuestion + Recommended pattern (#35)
- plan: Outer Loop test layer selection, Large Plans split decision — converted to AskUserQuestion + Recommended pattern (#35)
- ideate evals: added E1 assertion (Recommended pattern in approach selection) — total 10 assertions (#35)
- issue evals: added A4 assertion (Recommended in Priority confirmation) — total 13 assertions (#35)
- bug evals: added A3 assertion (Recommended in Fix Proposal) — total 5 assertions (#35)
- discover evals: added A10 assertion (Recommended in key decision points) — total 23 assertions (#35)
- plan evals: added A5 assertion (Recommended in Story Test layer selection) — total 10 assertions (#35)

## [1.9.0] - 2026-04-13

### Added
- plan: Agent Composition section added to plan deliverables — Step 4 derivation guidance, Step 6 template, and Step 5 Readiness Check row (#41)
- tests: `test_plan_agent_composition.bats` with 13 tests covering AC2-AC7 (#41)

### Changed
- autopilot: Variable-Count Agents now spawned directly from plan-approved Agent Composition — no additional user approval required at Phase 3/4 spawn time (#41)
- autopilot: Plan Review Round Developer instruction now includes Agent Composition review (count and focus concreteness) (#41)
- autopilot: Phase 0.9 mid-phase resume now validates plan comment exists before proceeding to Phase 3/4; reports error and STOPs if absent (#41)

## [1.8.0] - 2026-04-13

### Added
- discover: DoD (Definition of Done) derivation step (Step 2.5) added to Development, Bug, and Refactoring flows (#36)
- discover: DoD derivation step added to Documentation/Research flow (replaces Completion Criteria) (#36)
- discover: DoD section now appears at the top of all Issue comment templates across all task types (#36)
- discover: Refactoring flow requires a DoD item confirming externally observable behavior is unchanged (#36)
- tests: `test_discover_dod_structure.bats` with 26 tests covering AC1-AC9 (#36)

### Changed
- discover: "Completion Criteria" terminology replaced with "DoD (Definition of Done)" throughout all flows (#36)
- discover: Documentation/Research flow Step 3 renamed from "Define Completion Criteria" to "DoD Derivation" (#36)
- plan: Step 1 and description updated to read DoD + ACs from discover deliverables (#36)
- docs/issue-ready-flow.md: "completion criteria" references updated to "DoD" (#36)
- commands/autopilot.md: "completion criteria" reference updated to "DoD items" (#36)

## [1.7.0] - 2026-04-12

### Added
- 7-agent architecture: tester.md, reviewer.md, writer.md agents added alongside existing po, developer, qa, researcher (#34)
- Task-type-specific workflow branching in autopilot: development, bug, research, documentation, refactoring each have distinct agent compositions (#34)
- Agent Composition Table mapping task types to Phase 1/Phase 2 agent sets (#34)
- Variable-count agents (Reviewer, Researcher) with user approval flow (#34)
- AUTOPILOT-GUARD STOP mode for discover, plan, atdd, verify, ship skills — prevents direct invocation outside autopilot (#34)

### Changed
- `ready-to-implement` label renamed to `ready-to-go` across all skills, commands, docs, and templates (#34)
- `type:investigation` label renamed to `type:research` with corresponding template and flow updates (#34)
- investigation.yml Issue templates renamed to research.yml (en and ja) (#34)
- Phase 3/4 headings changed to "(task-type-specific)" reflecting multi-flow design (#34)

## [1.6.1] - 2026-04-12

### Fixed
- discover/plan/atdd: autopilot mode detection migrated from `<teammate-message>` context to `--autopilot` flag in ARGUMENTS, fixing PO direct Skill invocation not being recognized as autopilot mode (#3)
- autopilot.md: Phase 1 (discover) and Phase 3 (atdd) Skill calls now pass `--autopilot` flag in args (#3)

## [1.6.0] - 2026-04-12

### Added
- New `record` skill: generates Decision Record in `docs/decisions/YYYY-MM-DD-<topic>.md` after ship completes (#13)
- `ship` Step 11: chains to `record` skill after merge for automatic Decision Record generation (#13)
- `discover` deliverables template: `### Discussion Summary` section for recording approach exploration and rationale (#13)
- `plan` deliverables template: `### Discussion Summary` section for recording design decisions and trade-offs (#13)

## [1.5.1] - 2026-04-12

### Fixed
- pr-screenshot-table.sh: AWK code injection prevention — use `-v` option instead of shell expansion for file path (#26)
- pr-screenshot-table.sh: safe image_paths expansion — convert string concatenation to bash array, remove SC2086 disable (#26)
- pr-screenshot-table.sh: add PR number input validation with integer regex check (#26)
- .gitignore: add `*.local.*`, `*.secret`, `*.secrets` catch-all patterns (#26)
- eval-guard.sh: use three-dot diff (`origin/main...HEAD`) to detect only branch-introduced SKILL.md changes, preventing false positives when main advances (#22)
- eval-guard.sh: strengthen `git push` detection regex to avoid false positives from "git push" in command arguments (#22)

## [1.5.0] - 2026-04-12

### Changed
- sim-pool-guard.sh: redesign from fail-closed to fail-open — unlisted tools now ALLOW instead of DENY (#21)
- sim-pool-guard.sh: XcodeBuildMCP clone-required tools use `*_sim` pattern matching via `is_xcode_clone_required()` instead of explicit array (#21)
- sim-pool-guard.sh: rename `CLONE_REQUIRED_TOOLS` to `CLONE_REQUIRED_IOS_SIM` with updated ios-simulator tool names (#21)

### Added
- sim-pool-guard.sh: `DENY_TOOLS` array for golden image protection — `erase_sims` unconditionally denied (#21)
- sim-pool-guard.sh: `is_xcode_clone_required()` function for `*_sim` suffix pattern + `screenshot`, `snapshot_ui`, `session_set_defaults`, `session_use_defaults_profile` (#21)
- sim-pool-guard.sh: DENY check runs before session_id check — `erase_sims` blocked even without session (#21)

### Removed
- sim-pool-guard.sh: `READONLY_TOOLS` array — superseded by fail-open default (#21)

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

