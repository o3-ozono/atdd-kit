# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.23.0] - 2026-04-20

### Added
- `scripts/test-skills-headless.sh`: integration runner for skill-chain tests. Supports `--replay <transcript> <scenario>` (deterministic, zero-token) and live mode (`claude -p --output-format stream-json --include-partial-messages --no-session-persistence`). Env overrides `HEADLESS_CLAUDE_BIN` / `HEADLESS_TEMP_DIR` for testability. SIGINT/SIGTERM terminates the subprocess and cleans up the transcript tempdir. (#72)
- `lib/skill_transcript_parser.sh`: jq-based parser extracting `type=tool_use && name=Skill` events from stream-json into a JSON array of `{name, args, order}`. Strict schema validation: missing `input.skill`, malformed JSON per line, and non-UTF-8 input all fail with `exit 2` (`parse_error`). Subagent-invoked tool_use (`parent_tool_use_id != null`) is filtered out. (#72)
- `lib/skill_assertion.sh`: match engine with `--mode subsequence|strict`, `--expected`, `--forbidden`, `--observed` JSON array flags. Subsequence allows intermediate skills; strict requires exact equality; forbidden hits FAIL regardless of mode. Exit codes: `0` PASS, `1` FAIL, `3` infra. (#72)
- `lib/scenario_loader.sh`: validates scenario spec JSON (version/name/prompt/expected_skills/forbidden_skills/match_mode/timeout/model/fixture) and emits normalized output. Schema violations -> `exit 3`. (#72)
- `tests/fixtures/headless/`: Group-A synthetic fixtures for happy/fail/malformed/schema paths, Group-B real-session fixture `skill-gate-discover.happy.jsonl` (144 lines, Haiku recording, sanitized host paths), plus scenario JSONs for each. (#72)
- `tests/test_skill_transcript_parser.bats` (17 cases), `tests/test_skill_assertion.bats` (17 cases), `tests/test_headless_runner.bats` (13 cases -- flags / SIGINT / live stub / tempdir retention), `tests/test_headless_exit_codes.bats` (12-case matrix across all exit code categories), `tests/test_pr_workflow_headless.bats` (10 cases verifying CI integration). All run in the new `headless-replay` PR job and do not invoke `claude`. (#72)
- `.github/workflows/pr.yml`: new `headless` paths-filter output and `headless-replay` job. Filter scope is narrow (skills/**, headless test own files, workflow YAMLs) to avoid flaky CI from unrelated edits; `hooks/`, `agents/`, `commands/` intentionally excluded in MVP. `ci-gate` now depends on `headless-replay`. (#72)
- `.github/workflows/headless-live.yml`: workflow_dispatch-only live runner. Requires `ANTHROPIC_API_KEY` secret; installs Claude Code CLI; accepts scenario path and model override inputs; uploads transcript artifact on failure. Never triggers on `pull_request` or `push`. (#72)
- `docs/guides/headless-skill-testing.md`: usage guide, regression coverage matrix, scenario spec schema, recording + sanitize procedure, engineered-prompt rationale for the skill-gate -> discover fixture, and budget notes. (#72)
- `DEVELOPMENT.md` + `DEVELOPMENT.ja.md`: "Skill rename = semver-breaking" policy under Versioning. Renaming or removing a shipped skill id breaks pinned scenario fixtures and requires a major bump + fixture re-recording + CHANGELOG `BREAKING CHANGE:` entry. (#72)

## [1.22.0] - 2026-04-18

### Added
- `hooks/autopilot-worktree-guard.sh` + `hooks/autopilot_worktree_guard.py`: PreToolUse hook enforcing that autopilot sessions cannot Edit/Write/MultiEdit/NotebookEdit or Bash-mutate files outside the active worktree. Gated by `ATDD_AUTOPILOT_WORKTREE` env var — no-op for normal (non-autopilot) sessions. Allow-list: `/tmp`, `/var/folders`, `/private/var/folders`, `/private/tmp`, `/dev/null`, and `<W>/.git`. Bash tokenization uses `shlex` (quoted literals and `2>&1` are not misdetected). Blocks exit 2 with `worktree=<W>\nviolating=<path>` on stderr. (#111)
- `hooks/hooks.json`: PreToolUse matchers extended — `Edit|Write|MultiEdit|NotebookEdit` now chains the new guard after `main-branch-guard.sh`, and a new `Bash` matcher invokes the guard. (#111)
- `commands/autopilot.md` Phase 0.9 Step 4: autopilot sessions must export `ATDD_AUTOPILOT_WORKTREE=$(realpath <worktree>)` immediately after `EnterWorktree`. (#111)
- `tests/test_autopilot_worktree_guard.bats`: 46 cases covering AC1-AC6 including Bash-parsing edges (quoted `>`, `2>&1`, `>|`, `&>`, `&>>`, `;` separator, `$()` outer redirect, `~` expansion, heredoc outer redirect, symlink escape, chained `&&`, pipe `|`, `/dev/null`). (#111)
- `tests/test_autopilot_phase09_env_export.bats`: drift-resistant assertion on the `commands/autopilot.md` Phase 0.9 section containing `ATDD_AUTOPILOT_WORKTREE`, `export`, and `realpath` tokens (AC1 regression guard). (#111)
- `hooks/README.md`: section documenting the new hook's behavior, allow-list, block contract, and Known Limitations (mirrors CHANGELOG). (#111)

### Known Limitations (intentional deferrals, #111)
- heredoc file targets (`cat <<EOF > /etc/x`) — not detected; deferred.
- Nested subshell mutations (`$(cmd > path)`) — only outer is inspected.
- `eval "cmd > path"` / `bash -c "cmd > path"` — command strings are opaque to the guard.
- `exec >path` redirects — not detected.
- Interpreter-level file IO (`python -c "open('/p','w')..."`) — target is a Python string literal, unreachable for shlex.
- All of the above are partly mitigated by the `/tmp` allow-list and by Edit/Write/MultiEdit/NotebookEdit being covered separately.
- Requires `python3` in `$PATH` (used for JSON parsing + shlex tokenization). Standard on macOS and CI; unavailability falls back to no-op.

## [1.21.1] - 2026-04-17

### Added
- `docs/personas/hiro-solo-dev.md`: Primary persona for atdd-kit itself — a solo developer running atdd-kit on personal projects. Grounded in the repository's actual single-maintainer commit pattern, project-scope Quick Start, and autopilot's PO-solo design. (#110)
- `docs/personas/rin-freeform-coder.md`: Negative persona — a freeform coder who rejects Issue-driven / AC-first process. Documents the scope boundary so future design decisions do not dilute guardrails under "freeform" pressure. (#110)

### Changed
- `docs/personas/README.md`: Convention table extended with `hiro-solo-dev.md` (Primary) and `rin-freeform-coder.md` (Negative) entries. (#110)
- `docs/methodology/persona-guide.md`: "Creating a Persona Before Running Autopilot" section appended with an "Example: atdd-kit's Own Persona Library" subsection linking to the two persona files above. (#110)

## [1.21.0] - 2026-04-17

### Added
- `commands/autopilot.md`: Phase 5 を `### development / bug / documentation / refactoring` と `### research` の二段 H3 に分割。research タスクは PR verify/merge をスキップし、deliverable 分類 → Issue 起票/コメント → クロージングコメント → 元 Issue クローズ → label 削除 → ExitWorktree/TeamDelete へルーティングされる。(#104)
- `commands/autopilot.md`: Agent Composition Table 直下に Phase 5 note 追加（research は PR verify/merge スキップを明示）。(#104)
- `commands/autopilot.md`: research H3 に classification heuristic 追加（`new_issue` / `existing_comment` / `no_action`、迷ったら `existing_comment` 優先）。(#104)
- `tests/test_autopilot_research_phase5.bats`: AC1-AC9 全件の BATS テスト 30 ケース。(#104)

### Changed
- `tests/test_autopilot_review_gate.bats`: sed 範囲パターンを H2 限定に修正（H3 挿入後も Phase 5 範囲が正しく抽出されるよう対応）。(#104)
- `evals/footprint/baseline.json`: autopilot checkpoint baseline を再測定（commands/autopilot.md +15.7%、plan R2 で想定済み）。(#104)

## [1.20.0] - 2026-04-17

### Changed
- `agents/{developer,qa,tester,reviewer,researcher,writer}.md`: removed pinned `model: sonnet` and `effort: high` frontmatter fields. Agents now inherit model and effort from session-level Claude Code settings (`/model`, `/effort`), allowing users to select Opus 4.7 or other models without editing plugin files. (#105)
- `agents/README.md`: removed `Model` and `Effort` columns from Agent table; removed `model` row from Frontmatter Reference; added session-inheritance note.

### Added
- `tests/test_issue_105_frontmatter_session_inheritance.bats`: regression guard (4 tests) verifying no pinned model/effort fields and README session-inheritance documentation. (#105)

## [1.19.0] - 2026-04-16

### Fixed
- `skills/discover/SKILL.md`: Step 7 autopilot mode now outputs `skill-status` block only — explicitly excludes draft AC listings, UX check results, Interruption check results, and Discussion Summary from terminal output. (#101)
- `skills/discover/SKILL.md`: Bug Flow Step 5 now has independent autopilot/standalone mode branches instead of implicit reference to development flow Step 7. (#101)
- `commands/autopilot.md`: Phase 1 now explicitly states Phase 1 is not complete until AC Review Round agents have been spawned; receiving SKILL_STATUS: COMPLETE from discover alone does not complete Phase 1. (#101)

### Added
- `tests/test_autopilot_phase1_transition.bats`: 14 BATS tests covering AC1 (discover output control), AC2 (Phase 1 completion condition), and AC3 (immediate transition regression). (#101)

## [1.18.0] - 2026-04-16

### Added
- `skills/discover/SKILL.md`: Step 3 persona lookup and bootstrap flow — lists available personas from `docs/personas/` (excluding README.md/TEMPLATE.md) and presents them as AskUserQuestion options; if no personas exist, prompts user to create one following `docs/personas/TEMPLATE.md` format and saves to `docs/personas/<name>.md` (D6 documentation artifact exception). (#69)
- `skills/discover/SKILL.md`: Step 4.5 US/AC Quality Validation gate (development flow only) — validates MUST-1 (named persona reference), MUST-2 (≥3 ACs), and MUST-3 (independently verifiable Then clauses) with blocking enforcement and max-2-revision escalation; checks SHOULD-1 through SHOULD-5 and anti-pattern categories with individual ID-tagged non-blocking advisory. (#69)
- `skills/discover/SKILL.md`: Step 8 spec file creation (standalone mode only) — creates `docs/specs/<kebab-slug>.md` per `docs/methodology/us-ac-format.md` format with `status: approved` frontmatter after Issue comment posting (D6 documentation artifact exception). (#69)
- `skills/discover/evals/evals.json`: 8 new eval cases (id 6-13) covering persona listing, persona bootstrap, MUST-1/2/3 individual violation blocking, SHOULD advisory non-blocking reporting, spec file creation in standalone mode, and spec file skip in autopilot mode. (#69)

### Changed
- `skills/discover/SKILL.md`: D6 principle updated to explicitly list documentation artifact exceptions (`docs/personas/` and `docs/specs/` only). (#69)
- `skills/discover/SKILL.md`: Mandatory Checklist updated to include Step 3a persona selection, Step 4.5 quality validation, SHOULD advisory, D6 exception guard, and spec file creation items. (#69)
- `skills/discover/evals/evals.json`: id:0 (dev-feature) updated — `files` fixture adds `docs/personas/kenji-analyst.md`, assertion A2 extended to require named persona reference from `docs/personas/`. (#69)
- `docs/methodology/atdd-guide.md`: User Story section adds MUST-1 cross-reference to `us-quality-standard.md`; AC Rules section adds MUST-3 independent verifiability link. (#69)

## [1.17.0] - 2026-04-16

### Added
- `docs/methodology/us-quality-standard.md`: New User Story quality standard document with MUST/SHOULD/Anti-pattern/LLM guidelines sections. MUST criteria enforce existing format rules (persona reference, 3+ AC count, independent verifiability). SHOULD criteria apply QUS-derived quality goals (well-formed, atomic, minimal, problem-oriented, unambiguous). Anti-pattern reference covers 3 smell categories with 9 bad examples and suggested rewrites. LLM guidelines scope overview with defer note linking to Issue #69. (#68)
- `docs/methodology/README.md`: New directory index listing all methodology documents with one-line descriptions. (#68)
- `tests/test_us_quality_standard.bats`: 29 BATS tests covering all 6 ACs and language policy for the new quality standard. (#68)

## [1.16.1] - 2026-04-16

### Fixed
- `commands/autopilot.md`: Phase 5 Step 6 の ExitWorktree 呼び出し前に `git switch worktree-autopilot-{issue_number}` を追加。worktree の HEAD が feature ブランチに移動した状態でも ExitWorktree が `discard_changes: true` なしで完了できるよう修正。(#97)
- `tests/test_worktree_isolation.bats`: Phase 5 内で `git switch worktree-autopilot-` パターンが ExitWorktree より前に出現することを機械検証するテスト 2 件を追加。(#97)

## [1.16.0] - 2026-04-16

### Added
- `skills/express/SKILL.md`: New Express skill providing a fast path for trivial, low-risk changes (typo fixes, `.gitignore` additions, one-line comments). Bypasses discover/plan/Three Amigos/review while maintaining Issue-driven development, CI gate, version bump, and CHANGELOG requirements. Requires explicit user approval and rationale before execution. (#94)
- `commands/express.md`: New `/atdd-kit:express <issue>` command that delegates to the Express skill. (#94)
- `docs/guides/express-mode.md`: OK/NG applicability criteria for Express mode with concrete examples, governance table, and escalation guidance. (#94)
- `commands/setup-github.md`: Added `express-mode` label (color `5319E7`) to the repository label setup. Label count updated 13 → 14. (#94)

### Changed
- `skills/README.md`: Added Express skill entry and Express path documentation in Workflow Chain section. (#94)
- `commands/README.md`: Added Express command entry. (#94)
- `tests/test_skill_structure.bats`: Added `express` to `ALL_SKILLS` list. (#94)

## [1.15.1] - 2026-04-16

### Fixed
- `skills/atdd/SKILL.md`: Workflow Step 2 の曖昧な "Create branch: `feat/<issue-number>-<slug>`" を明示的な `git switch -c feat/<issue-number>-<slug>` コマンドに置き換え。refspec rewriting 禁止の WARNING を追加。autopilot Phase 5 の `ExitWorktree` が `discard_changes: true` なしに完了できるよう root cause を修正。(#90)

## [1.15.0] - 2026-04-15

### Added
- `scripts/measure-footprint.sh`: New script for static context/token footprint measurement. Supports `measure`, `--check`, and `--update` operations with JSON output and regression detection (+10% bytes OR +500 tokens threshold). (#76)
- `evals/footprint/session-start.yml`, `evals/footprint/autopilot.yml`: Checkpoint definitions for high-frequency entry points. (#76)
- `evals/footprint/baseline.json`: Initial baseline for session-start and autopilot checkpoints. (#76)
- `evals/footprint/README.md`: Schema documentation distinguishing footprint eval from behavioral pass_rate eval. (#76)
- `tests/test_footprint_eval.bats`: 48 BATS tests covering all 7 groups (happy path / math / lifecycle / threshold / dynamic / errors / E2E) + B1 guard. (#76)
- `.github/workflows/pr.yml`: `evals/**` added to `config` paths-filter so footprint CI runs on checkpoint/baseline changes. (#76)

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

