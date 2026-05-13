# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Removed
- **`tests/claude-code/` 配下を完全削除**: 旧 SAT 系ハーネス (`run-skill-tests.sh` / `samples/{fast,integration}-*.sh` 13 件 / `fixtures/` / `test-helpers.sh` / `analyze-token-usage.py` / `README.md`)。`scripts/run-skill-e2e.sh` + `tests/e2e/<skill>.bats` (#222) が完全代替。(#198 / #199 D1+D2 統合)
- **`tests/test_l4_*.bats` 5 件を削除**: `test_l4_samples` / `test_l4_test_helpers` / `test_l4_run_skill_tests` / `test_l4_analyze_token_usage` / `test_l4_docs`。廃止対象 `tests/claude-code/` を test 対象とする形骸化テスト。(#198 / #199)

### Changed
- **`tests/test_l4_lint_skill_descriptions.bats` → `tests/test_skill_description_lint.bats`**: rename。`scripts/lint_skill_descriptions.sh` を test 対象とする Unit Test で廃止対象に非依存のため中身ロジックは保持。(#198 / #199)
- `tests/README.md`: 「L4 Skill Tests (`tests/claude-code/`)」セクションを「Skill E2E Tests (`tests/e2e/`)」に置換。conventions と references の L4 言及も新語彙 (Unit Test / Skill E2E Test) に更新。(#198)
- `tests/test_skill_terminology_grep.bats`: 許容例外パスに `198-tests-claude-code-deprecation` を追加 (D1+D2 統合 Issue が旧用語の廃止を議論するため)。(#198)

### Added
- `scripts/run-skill-e2e.sh`: Skill E2E Test runner with path-based impact mapping. `--changed-files` でファイル変更リストから影響範囲を path-based に算定 (`skills/<X>/` → `tests/e2e/<X>.bats`、`rules/templates/methodology/` → 全 E2E、`lib/scripts/` → 利用元 SKILL.md cite skill)、`--all`、`--dry-run`、`--log-dir` 対応。`tests/e2e/.logs/<run-id>.log` に run-id / git_sha / timestamp / targets / results / summary を出力。(#222)
- `tests/test_run_skill_e2e_impact.bats`: runner の path-based マッピングと log 必須フィールドを検証する Unit Test 10 case。(#222)
- `tests/test_skill_terminology_grep.bats`: legacy skill testing terminology (SAT / L1-L3 / Fast layer / Integration layer / BATS gate / Fast SAT / Integration SAT) が active source に残らないことを検証。(#222)
- `tests/e2e/`: Skill E2E Test 配置ディレクトリ。`.logs/` は gitignore 済み、`.gitkeep` でディレクトリ自体は管理。(#222)
- `tests/e2e/defining-requirements.bats`: Skill E2E Test の最初の実体。1 skill = 1 ファイル、1 User Story = 1 `@test` の構造で、実 claude を `claude -p --max-turns 1` で呼び出して PRD 6 section / upstream→downstream chain order / 出力 path を検証。`scripts/run-skill-e2e.sh --changed-files skills/defining-requirements/SKILL.md` で path-based 影響範囲算定 → 実 claude 実行 → ログ出力までを通しで実証。(#222)
- `docs/issues/222-skill-test-redesign/`: PRD / user-stories / plan / acceptance-tests。Step 2-3 は B2 (#189) / B3 (#190) skill 未実装のため手動代行。(#222)

### Changed
- **Renamed: skill testing terminology.** v1.0 で「SAT (Skill Acceptance Test) / L1 BATS gate / L2 Fast SAT / L3 Integration SAT / Fast layer / Integration layer」を全廃し **Unit Test (claude を呼ばない BATS) / Skill E2E Test (実 claude 起動)** の 2 層に統一。`docs/testing-skills.md` が新体系の単一の正典。CHANGELOG.md / `docs/testing-skills.md` の廃止宣言 / `docs/issues/222-*` / `docs/issues/179-*` には移行ガイドとして旧用語を保持。(#222)
- `docs/testing-skills.md`: 2 層体系 / 影響範囲算定ロジック / 証跡コメント規約（最新 1 件 update 運用ルール含む） / 1 skill = 1 E2E ファイル構造例で全面書き換え。(#222)
- `tests/test_defining_requirements_skill.bats`, `tests/claude-code/run-skill-tests.sh`, `tests/claude-code/samples/{fast,integration}-*.sh`: 内部コメントの「Fast layer / Integration layer / Skill Acceptance Test」表記を「Skill E2E Test (single-turn) / Skill E2E Test (fixture-based chain) / Skill E2E Test」に置換。ファイル名のリネームは別 PR。(#222)

- `skills/defining-requirements/SKILL.md`: v1.0 Step 1+2 implementation. 64-line orchestrator that walks the author through the 6 PRD sections (Problem / Why now / Outcome / What / Non-Goals / Open Questions) one question at a time, then writes `docs/issues/<NNN>/prd.md`. Scope ends at the PRD (User Story extraction is owned by `extracting-user-stories` #189). Subagent invocation and `in-progress` label management are explicitly out of scope. (#188)
- `tests/claude-code/samples/fast-defining-requirements.sh` + `tests/claude-code/fixtures/defining-requirements-keywords.txt`: Fast-layer Skill Acceptance Test. Verifies that an LLM reading the SKILL.md recovers PRD 6 sections, upstream/downstream skill names with correct order, output path and trigger, and dialog discipline. (#188)
- `tests/test_defining_requirements_skill.bats`: 6 @test gates — responsibility boundary (output path, downstream skill, subagent and label scope) and line budget (≤200). Wording-level checks delegated to the Fast SAT. (#188)

### Changed
- `tests/test_v1_skill_skeletons.bats`: Split `V1_SKILLS` into a skeleton-only `SKELETON_SKILLS` array. `defining-requirements` is removed from the skeleton list. Each future B PR (#189–#195) follows the same one-line removal. (#188)

### BREAKING Changes (v1.0 — Step E6)

- **Persona concept removed.** v1.0 (#218) drops the persona model entirely. User Stories use **persona-less Connextra** (`I want to <goal>, so that <reason>`). The following are removed: `docs/personas/` directory, `lib/persona_check.sh`, `docs/methodology/persona-guide.md`, `scripts/check-persona-check-order.sh`, `tests/test_persona_check.bats`, `tests/test_persona_guide.bats`, `agents/us-reviewer.md` criteria #2 (named persona) / #5 (INVEST) / #6 (persona traceability), `lib/spec_check.sh::spec_persona` subcommand, `docs/specs/TEMPLATE.md` persona frontmatter field, and persona-related sections in `docs/methodology/{us-ac-format,us-quality-standard,definition-of-ready,scrumban,atdd-guide}.md`. Applied projects with `docs/personas/` must migrate User Stories to the persona-less form (manual migration required). (#218)
- **Example Mapping not adopted.** Inherited #169 (旧 Phase C: Backlog Refinement evolution) machinery was never part of #179 v1.0 PRD's "採用する設計判断" table. Explicitly removed from sub-issue ACs (#188 / #189). (#216 / #218)
- **INVEST not adopted.** Same provenance as Example Mapping. `agents/us-reviewer.md` criterion #5, `docs/methodology/definition-of-ready.md` R5, and `docs/methodology/us-quality-standard.md` SHOULD references removed. (#216 / #218)
- **Story Splitting (US methodology) not adopted.** `docs/methodology/story-splitting.md` removed. The "Story Splitting" naming in #179 epic refers to **PR splitting** (about 26 sub-PRs), not US methodology splitting. (#216 / #218)

### Changed
- `agents/us-reviewer.md`: Reduced from 10 to 7 criteria after removing #2 (named persona), #5 (INVEST), #6 (persona traceability). Connextra form criterion #1 rewritten as `I want to <capability>, so that <outcome>` (persona-less). (#218)
- `agents/final-reviewer.md`: Total traceability references reduced from 50 to 47 to mirror the us-reviewer change. (#218)
- `agents/qa.md`, `agents/developer.md`: AC Review note "persona's `I want to`" generalized to "`I want to`". (#218)
- `templates/docs/issues/user-stories.md`: `[persona]` placeholder removed; functional and constraint stories use persona-less Connextra. (#218)
- `templates/issue/en/development.yml`: User Story placeholder rewritten as persona-less Connextra. (#218)
- `docs/methodology/us-quality-standard.md`: MUST-1 (Persona Reference) removed; MUST-2/3/4 renumbered to MUST-1/2/3. SHOULD examples rewritten to persona-less form. (#218)
- `docs/methodology/definition-of-ready.md`: R2 rewritten to persona-less Connextra; R5 (INVEST) and R6 (Story Splitting) removed; R7 renumbered to R5. (#218)
- `docs/methodology/us-ac-format.md`: persona frontmatter field removed from schema; field order reduced to `title / issue / status`; TBD Persona Rule section removed. (#218)
- `docs/methodology/scrumban.md`: persona / Hiro / Story Splitting / persona-guide references removed. (#218)
- `docs/methodology/atdd-guide.md`: User Story format rewritten as persona-less Connextra; MUST-1 reference removed; constraint story example rewritten without persona. (#218)
- `docs/methodology/README.md`: persona-guide.md / story-splitting.md rows removed. (#218)
- `docs/README.md`: `personas/` section removed; methodology table cleared of persona-guide / story-splitting rows. (#218)
- `docs/specs/TEMPLATE.md`, `docs/specs/README.md`, `docs/specs/us-ac-format.md`, `docs/specs/llm-us-ac-auto-reference.md`: persona frontmatter field and User Story persona placeholder removed. (#218)
- `docs/guides/spec-reference.md`: AC6 Fallback Matrix `tbd-persona` row removed; Order Invariant `persona check` precedence removed. (#218)
- `docs/workflow/skill-fix-flow.md`: discover SKILL.md row updated to mark persona auto-select as removed in #218. (#218)
- `skills/bug/SKILL.md`: spec-cite step text simplified to remove `tbd-persona` reference. (#218)
- `lib/spec_check.sh`: `spec_persona` subcommand and `tbd-persona` warn case removed. (#218)
- `tests/test_reviewer_subagents.bats`: AC2 us-reviewer category list reduced to `Connextra` + `制約 Story`; AC2 forbidden-category guard added; AC3 reviewer-specific criteria count (us-reviewer=7, others=10); AC4 traceability count reduced from 50 to 47 with role-specific N range. (#218)
- `tests/test_spec_check.bats`: `_make_spec` helper persona arg removed; `spec_persona` subcommand existence test replaced with removal verification. (#218)
- `tests/test_spec_reference.bats`: Group 1 atdd "persona check precedes spec check" test removed. (#218)
- `tests/test_us_ac_format.bats`: persona frontmatter assertions converted to negative guards. (#218)
- `tests/test_us_quality_standard.bats`: persona-related assertions converted to negative guards; MUST-4 references renumbered to MUST-3. (#218)
- `docs/issues/179-atdd-kit-v1-redesign/prd.md`: Step A0 PRD revision — explicitly marked **persona / Example Mapping / INVEST / Story Splitting (US methodology)** as **不採用 (not adopted)** in v1.0. User Story format changed to **persona-less Connextra** (`I want to <goal>, so that <reason>`). Resolved all 4 Open Questions: subagent review = serial execution, dogfood timing = after Step E5, post-deploy regression mechanism and launching-preview args are deferred to #193 / #194 discover phases. Added Step A0 and E6 (persona machinery removal) to the Step structure. (#216)
- `skills/discover/SKILL.md`, `skills/plan/SKILL.md`, `skills/atdd/SKILL.md`, `skills/verify/SKILL.md`, `skills/ship/SKILL.md`: Removed `<AUTOPILOT-GUARD>` blocks from all 5 skills. Standalone slash-command invocation (e.g. `/atdd-kit:discover 188`) now works without `--autopilot`. Autopilot-mode behavioral branches preserved. Precursor partial of #202. (#214)

### Removed
- `docs/personas/` directory (all files: README, TEMPLATE, hiro-solo-dev.md, rin-freeform-coder.md). (#218)
- `lib/persona_check.sh`, `scripts/check-persona-check-order.sh`. (#218)
- `docs/methodology/persona-guide.md`. (#218)
- `docs/methodology/story-splitting.md` (US methodology splitting concept dropped; #179 epic's "Story Splitting" refers to PR splitting). (#218)
- `tests/test_persona_check.bats`, `tests/test_persona_guide.bats`. (#218)

### Removed
- `tests/test_autopilot_guard_block.bats`: Obsolete after `<AUTOPILOT-GUARD>` blocks were removed from 5 skills. The test asserted GUARD block presence and STOP behavior which no longer exists. (#214)
- BATS tests asserting `<AUTOPILOT-GUARD>` presence in `discover`/`plan`/`atdd` SKILL.md files (`test_discover_dod_structure.bats`, `test_discover_autopilot_approval.bats`, `test_discover_skill_fix_bypass.bats`, `test_skill_fix_flag_scope.bats`) — obsolete after GUARD removal. (#214)

## [2.5.1] - 2026-05-11

### Changed
- `rules/atdd-kit.md`: Workflow section replaced with the v1.0 6-step table (Discovery & Definition / User Stories / Plan / ATDD / Review / Merge) listing the 6 new capability-name skills and `docs/issues/<NNN>/` deliverable paths. Added "1 Issue = 1 worktree = 1 Draft PR" to PRs section and "Open Draft PR on first commit/push" to Commits section. (#187)
- `CLAUDE.md`: Added Workflow overview section mirroring the 6-step table with concrete deliverable paths under `docs/issues/<NNN>/`; preserved existing DEVELOPMENT.md / CHANGELOG.md references. (#187)
- `DEVELOPMENT.md`, `DEVELOPMENT.ja.md`, `rules/README.md`: Always-loaded rules budget raised from 40 to 60 lines (v1.0 migration concession); each location notes the re-tighten target tied to Step E. (#187)

### Added
- `tests/test_rules_workflow.bats`: New BATS suite (11 @test functions) mechanically verifying AC1-AC5 of #187 — 6 step names + 6 skill names + ≤60 line budget (AC1), 5 grep checks on CLAUDE.md (AC2), case-insensitive autopilot absence (AC3), verbatim "1 Issue = 1 worktree = 1 Draft PR" (AC4), Draft PR + first/initial commit/push regex (AC5). (#187)

## [2.5.0] - 2026-05-11

### Added
- `skills/defining-requirements/SKILL.md`: v1.0 skeleton — Step 1+2 Discovery & Definition. HARD-GATE blocks execution until #179 Step B1 is implemented. (#185)
- `skills/extracting-user-stories/SKILL.md`: v1.0 skeleton — Step 3 User Story extraction. HARD-GATE blocks execution until #179 Step B2 is implemented. (#185)
- `skills/writing-plan-and-tests/SKILL.md`: v1.0 skeleton — Step 4 Plan + Acceptance Tests. HARD-GATE blocks execution until #179 Step B3 is implemented. (#185)
- `skills/running-atdd-cycle/SKILL.md`: v1.0 skeleton — Step 5 ATDD implementation cycle. HARD-GATE blocks execution until #179 Step B4 is implemented. (#185)
- `skills/reviewing-deliverables/SKILL.md`: v1.0 skeleton — Step 6 Review. HARD-GATE blocks execution until #179 Step B5 is implemented. (#185)
- `skills/merging-and-deploying/SKILL.md`: v1.0 skeleton — Step 7 Merge + Deploy. HARD-GATE blocks execution until #179 Step B6 is implemented. (#185)
- `skills/launching-preview/SKILL.md`: v1.0 skeleton — on-demand local preview. HARD-GATE blocks execution until #179 Step B7 is implemented. (#185)
- `skills/writing-design-doc/SKILL.md`: v1.0 skeleton — on-demand design document. HARD-GATE blocks execution until #179 Step B8 is implemented. (#185)
- `tests/test_v1_skill_skeletons.bats`: BATS smoke test (11 @test functions) verifying all 8 v1.0 skeleton skills for existence, frontmatter conformance, HARD-GATE, Integration section, and ≤50 line constraint. (#185)

### BREAKING Changes (inherited from 2.0.0 — still in effect)
- `--light` and `--heavy` flags removed (see [2.0.0] for full migration guide). Use `spawn_profiles.custom` in `.claude/config.yml` or `--profile="..."`. (#122)

### Removed
- `hooks/autopilot-worktree-guard.sh`, `hooks/autopilot_worktree_guard.py`, `hooks/eval-guard.sh` と対応テスト・設定エントリ: autopilot / evals 機構削除（#179 Step E1/E3）に先行して hook 安全網を除去。(#182)

### Fixed
- `hooks/main-branch-guard.sh` + `hooks/main_branch_guard.py` (new): allow-list for repo-external paths (`/tmp`, `/var/folders`, `/private/var/folders`, `/private/tmp`, `/dev/null`, `~/.claude/`, `~/.config/`) on `main`/`master`; deny message updated to skill-name-agnostic wording; BATS suite extended to 47 cases covering AC1–AC5. (#181)

### Added
- `agents/prd-reviewer.md`, `agents/us-reviewer.md`, `agents/plan-reviewer.md`, `agents/code-reviewer.md`, `agents/at-reviewer.md`: 5 specialist reviewer subagent definitions for the new 6-step ATDD flow (#179 Step A3). Each enumerates 10 verifiable criteria covering the Issue-specified categories (PRD: 問題定義の明確性 / Audience / Outcome 測定可能性 / Non-Goals / Open Questions; US: Connextra / INVEST / 制約 Story / persona traceability; Plan: 2-5 分粒度 / verification / 依存関係; Code: Robot Pattern / testplan 分離 / AT 対応; AT: domain language / AT lifecycle / coverage). Frontmatter = `{name, description, tools}` with `Read, Grep, Glob` only. (#186)
- `agents/final-reviewer.md`: Final aggregator reviewer that names the 5 specialists by basename, cross-references all 50 criteria (10 per specialist via `<role>-reviewer#N` references), and defines the unified PASS/FAIL aggregation rule (PASS iff all 5 upstream reviewers report PASS). (#186)
- `tests/test_reviewer_subagents.bats`: 19-test structural smoke test covering AC1-AC6 of #186 — frontmatter shape, tools allowlist, AC2 category substring coverage, exactly-10 numbered criteria with verb/`?` constraint, 50 distinct traceability references in final-reviewer, and `name = basename` discoverability. (#186)
- `docs/methodology/scrumban.md`: `## GitHub Project` section — Project URL (`<TBD>` placeholder, auto-replaced by `setup-project.sh` on first run), 7-field schema (6 custom fields + Iteration), Status↔autopilot label mapping table with intentional gap note for "Shaped (Pitch済)". (#168)
- `scripts/setup-project.sh`: idempotent CLI script for GitHub Projects v2 setup — project create guard, Status + 5 custom fields creation, all Open Issue bulk-add, bulk field-set (uses `--single-select-option-id` and GraphQL node ID for `--project-id`); auto-replaces `projects/<TBD>` placeholder in scrumban.md with the real project URL on first run. (#168)
- `scripts/verify-project.sh`: automated verification script for AC2 (item count + non-null field check) and AC5 (scrumban.md URL / field schema / mapping grep); also queries Iteration date ranges via GraphQL for AC4 evidence. (#168)
- `tests/test_github_projects_setup.bats`: 23-assertion BATS test suite covering AC1–AC5 for the setup scripts and scrumban.md GitHub Project section; includes placeholder/sed verification for AC5 URL handling. (#168)
- `tests/claude-code/samples/fast-atdd.sh`: fast L4 test verifying atdd skill meta-knowledge — 14-keyword `assert_contains` loop + 2-anchor `assert_order` (ready-to-go State Gate → verify transition). (#140)
- `tests/claude-code/fixtures/atdd-keywords.txt`: ordered keyword fixture for fast-atdd.sh. (#140)
- `tests/claude-code/samples/integration-atdd.sh`: integration L4 test verifying atdd headless invocation — `atdd-kit:atdd` tool_use, SKILL_STATUS declaration in skill-status fence, and State Gate `issue view --json labels` gh call. (#140)
- `tests/claude-code/fixtures/atdd-fixture-issue.md`: mock Issue fixture for atdd integration tests with approved ACs and plan strategy (no real GitHub Issue required). (#140)
- `tests/claude-code/samples/integration-atdd-chain.sh`: chain/triggering L4 test verifying atdd → verify auto-invocation via `skill_transcript_parser.sh` order assertion (atdd_count == 1, verify_count >= 1, verify_order > atdd_order). (#140)
- `tests/test_atdd_superpowers_discipline.bats`: BATS grep tests for atdd superpowers discipline — Rationalization table (`| Excuse | Reality |`), HARD-GATE single-block, Terminal-state clause. (#140)
- `tests/claude-code/test-helpers.sh`: `setup_gh_stub()` extended with optional `--labels "label1 label2"` flag — returns `[{"id":1,"name":"<label>"}]` in `issue view` response; default behavior (empty labels) unchanged for back-compat with all existing callers. (#140)

### Changed
- `agents/README.md`: Available Agents table extended with 6 new step-reviewer rows (prd/us/plan/code/at/final-reviewer). (#186)
- `tests/test_po_dev_qa.bats` `#45-AC5`: agent definition file count updated from 6 to 12 (6 role agents + 6 step-reviewer agents); intent comment notes that Step E5 (#206) will drop `agents/reviewer.md` and the count will become 11. (#186)
- `skills/atdd/SKILL.md`: `## State Gate` section wrapped with `<HARD-GATE>` block (mirroring discover); Rationalization table added (replaces "Red Flags", `| Excuse | Reality |` format); Terminal-state constraint clause added restricting post-atdd invocation to `atdd-kit:verify` only. (#140)
- `DEVELOPMENT.md` / `DEVELOPMENT.ja.md`: "Red Flags tables" → "Rationalization tables" concept name update (line 108). (#140)

- `tests/claude-code/samples/fast-discover.sh`: fast L4 test verifying discover skill meta-knowledge — 11-keyword `assert_contains` loop + 2-anchor `assert_order` (session-start → plan). (#138)
- `tests/claude-code/fixtures/discover-keywords.txt`: ordered keyword fixture for fast-discover.sh. (#138)
- `tests/claude-code/samples/integration-discover.sh`: integration L4 test verifying discover invocation and `SKILL_STATUS: COMPLETE` in skill-status fence via jsonl transcript. (#138)
- `tests/claude-code/fixtures/discover-fixture-issue.md`: mock Issue fixture for integration tests (no real GitHub Issue required). (#138)
- `tests/claude-code/samples/integration-discover-chain.sh`: chain/triggering L4 test verifying discover → plan auto-invocation via `skill_transcript_parser.sh` order assertion. (#138)
- `tests/test_discover_superpowers_discipline.bats`: BATS grep tests for discover superpowers discipline — Rationalization table, HARD-GATE single-block, Terminal-state clause. (#138)
- `tests/claude-code/test-helpers.sh`: `setup_gh_stub()` helper added — creates a self-contained fake `gh` binary under `$tmpdir/gh-stub/` that intercepts `issue view/edit/comment` calls and logs all invocations to `gh-calls-<test-slug>.log`. Exports `GH_STUB_DIR` and `GH_STUB_LOG_FILE` (avoids subshell export problem). (#138)
- `skills/discover/SKILL.md` Step 4: US traceability table format instruction — each AC must map to a User Story element (`I want to` or `so that`); exclusion list overview (project conventions → DoD, trivial consequence → consolidate/omit, implementation guard → Implementation note, future Story → Plan test strategy). (#156)
- `skills/discover/SKILL.md` Step 4.5: MUST-4 "US Traceability" blocking criterion with fail markers, rewrite suggestions, single-source reference to `docs/methodology/us-quality-standard.md`, autopilot parity note (same behavior as MUST-1/2/3), and retroactive non-application caveat. (#156)
- `docs/methodology/us-quality-standard.md`: `### MUST-4: US Traceability` section with rule, Why, exclusion category table, Pass/Fail examples, retroactive non-application note. (#156)
- `agents/developer.md` / `agents/qa.md`: `## AC Review` section appended (identical content) — guides agents to require US element mapping before proposing new ACs, classify excluded categories, and prefer Then-clause strengthening over new AC addition. (#156)
- `skills/discover/evals/evals.json`: A13 assertion added to `dev-feature` eval for MUST-4 execution verification. (#156)

### Changed
- `skills/discover/SKILL.md`: description rewritten to `Use when` form; Rationalization table added; Terminal-state constraint clause added restricting post-discover invocation to `atdd-kit:plan` only. (#138)

## [2.4.0] - 2026-04-22

### Added
- `tests/claude-code/samples/fast-plan-skill-keywords.sh`: L4 fast test that verifies `skills/plan/SKILL.md` contains required anchors (`HARD-GATE`, `AUTOPILOT-GUARD`, `State Gate`, `## Core Flow`, `### Step 1`–`### Step 6`) in ascending line-number order using `grep -n` comparison. (#139)
- `tests/claude-code/samples/integration-plan-minimal.sh`: L4 integration test (guarded by `RUN_INTEGRATION=1`) that invokes `claude -p` against the minimal-project fixture and verifies the jsonl transcript contains `## Implementation Plan` and `### Test Strategy` markers. Stub-mode safe (skips content assertions when `SKILL_TEST_CLAUDE_BIN` is set). (#139)

### Changed
- `skills/plan/SKILL.md`: Applied Option X superpowers discipline — (a) description rewritten to "Use when …" trigger form; (b) `<IRON-LAW>` block added after `<HARD-GATE>`; (c) Rationalization table (`| Excuse | Reality |`) added after Core Principles; (d) `## Terminal State` section added before `## Status Output`. Existing `<HARD-GATE>`, `<AUTOPILOT-GUARD>`, and `ready-for-plan-review` label transition preserved. (#139)

## [2.3.0] - 2026-04-22

### Added
- `tests/claude-code/test-helpers.sh`: fast-test harness with `run_claude`, `assert_contains`, `assert_order`, `assert_count`, `create_test_project`. Supports `SKILL_TEST_CLAUDE_BIN` override for stub-based BATS testing. (#134)
- `tests/claude-code/run-skill-tests.sh`: fast/integration runner with `--test <name>`, `--integration`, `--verbose` flags. Exit codes 0/1/3/130/143. Supports `SKILL_TEST_TMPDIR`, `SKILL_TEST_CLAUDE_BIN`, `SKILL_TEST_PYTHON3_BIN` env overrides. SIGINT/SIGTERM cleanup. (#134)
- `tests/claude-code/analyze-token-usage.py`: per-agent token/cost breakdown from `claude -p` jsonl transcripts. Model-price map at script top; unknown models report N/A. Handles empty/malformed/non-UTF-8/missing files. (#134)
- `scripts/lint_skill_descriptions.sh`: scans `skills/*/SKILL.md` for description anti-patterns (step-chain keywords, length > 200 chars, dash-separator lists). WARN-only mode (exit 0). (#134)
- `tests/claude-code/samples/`: 4 sample tests — fast PASS (`fast-skill-description-lint.sh`), fast FAIL (`fast-intentional-fail.sh`), integration PASS (`integration-discover-minimal.sh`), integration FAIL (`integration-intentional-fail.sh`). (#134)
- `tests/claude-code/fixtures/minimal-project/`: minimal fixture project (`README.md` + `.claude/CLAUDE.md` stub) for integration tests. (#134)
- `docs/testing-skills.md`: L4 methodology — fast vs integration layers, jsonl analysis and pricing map update procedure, cost baseline (fast ≈ $0.10 / integration ≈ $5), adding new tests, linter WARN→FAIL escalation criteria. (#134)
- `tests/claude-code/README.md`: invocation prerequisites, env vars, GH_TOKEN hygiene, SIGINT/SIGTERM contract, exit codes, CI guard (`RUN_INTEGRATION=1`). (#134)
- `tests/fixtures/claude-code/`: BATS fixtures — `transcripts/` (valid/empty/malformed/non-utf8 jsonl), `lint_skill_descriptions/` (good/bad SKILL.md). (#134)
- `tests/test_l4_lint_skill_descriptions.bats`, `tests/test_l4_test_helpers.bats`, `tests/test_l4_analyze_token_usage.bats`, `tests/test_l4_run_skill_tests.bats`, `tests/test_l4_samples.bats`, `tests/test_l4_docs.bats`: BATS coverage for all AC1-AC6. (#134)
- `scripts/bats_runner.sh`: impact-scoped BATS runner. `--all` runs all 111 BATS files under `tests/` and `addons/*/tests/`; `--impact --base <ref>` delegates to `impact_map.sh` to run only affected tests, with automatic full-run fallback for unmatched changed files. Exits 0 with `no affected BATS` when diff is empty (AC5). Invalid base ref exits non-zero with error message (AC6). (#136)
- `scripts/check_bats_covers.sh`: validator that scans the first 5 lines of every BATS file for a non-empty `# @covers: <path-or-glob>` annotation. Exits 0 with `OK: N files` on success, non-zero with violation list on failure. (#136)
- `# @covers:` annotations added to all 111 BATS files (`tests/*.bats` + `addons/ios/tests/*.bats`). Annotation values follow `impact_rules.yml` token conventions for compatibility with both `scan_covers()` (glob-match) and `resolve_path_rules()` (substring-match) in `impact_map.sh`. (#136)
- `tests/test_check_bats_covers.bats`, `tests/test_bats_runner.bats`: BATS test files covering AC1-AC6. (#136)
- `tests/fixtures/impact/`: fixture files for validator and runner tests (valid/missing/empty_covers BATS + mock_impact_rules.yml). (#136)

### BREAKING Changes (inherited from 2.0.0 — still in effect)
- `--light` and `--heavy` flags removed (see [2.0.0] for full migration guide). Use `spawn_profiles.custom` in `.claude/config.yml` or `--profile="..."`. (#122)

## [2.2.0] - 2026-04-22

### Added
- `scripts/impact_map.sh`: maps git diff to affected tests via path rules (`config/impact_rules.yml`) and inline `@covers` metadata. Supports `--base <ref>`, `--layer {L4|BATS}`, `--all`, and `--config <path>`. Unmatched files trigger fallback to full scan with stderr diagnostics. Zero external dependencies (pure bash). (#135)
- `config/impact_rules.yml`: central path glob → L4/BATS test mapping for 7 path categories (skills, lib, hooks, agents, .claude-plugin, scripts, docs). (#135)
- `config/README.md`: schema reference for `impact_rules.yml` and extension policy. (#135)
- `docs/guides/testing-skills.md`: impact scope concept, `@covers` format definition, supported bash fnmatch subset, fallback behavior, and performance target. (#135)
- `tests/test_impact_map.bats`: 33 BATS cases covering AC1–AC8. (#135)

## [2.1.0] - 2026-04-21

### Added
- `skills/skill-fix/SKILL.md`: new skill for reporting atdd-kit skill defects during an active session without interrupting current work. Triggers via explicit `/atdd-kit:skill-fix` or implicit detection (skill name + intent verb). Runs 3-question interview, duplicate check, and dispatches a background subagent (`isolation: worktree`, `run_in_background: true`) that creates a new Issue and drives it to `ready-to-go` using the `--skill-fix` bypass on discover. (#119)
- `commands/skill-fix.md`: explicit slash command entry for skill-fix flow. (#119)
- `lib/skill_fix_dispatch.sh`: shell functions for dispatch, inflight registry (AC7), env scrubbing (AC8), completion check (AC6), and cleanup (AC9). (#119)
- `docs/workflow/skill-fix-flow.md`: workflow reference, Spike Results, #116 coexistence note, and audit marker regex. (#119)
- `templates/workflow/blocked_ac_comment.md`: template for `blocked-ac` blocker comments with `$phase`, `$failed_gate`, `$reason` placeholders. (#119)
- `tests/test_skill_fix_structure.bats`, `tests/test_skill_fix_dispatch.bats`, `tests/test_skill_fix_isolation.bats`, `tests/test_skill_fix_skill_md.bats`, `tests/test_skill_fix_beta_dispatch.bats`, `tests/test_skill_fix_env_contract.bats`, `tests/test_skill_fix_flag_scope.bats`, `tests/test_skill_fix_blocked_ac.bats`, `tests/test_skill_fix_audit_marker.bats`, `tests/test_discover_skill_fix_bypass.bats`: 10 bats test files covering AC1-AC10. (#119)
- `tests/fixtures/skill-fix/`: fixtures for dummy_skill_pass (GREEN scenario), dummy_skill_fail (RED scenario), inflight_registry_sample.json (AC7), issues.json (AC3 4-class). (#119)
- `skills/skill-fix/evals/evals.json` + `baseline.json`: 10 eval cases (trigger/interview/duplicate/dispatch), initial pass_rate 1.0 baseline. (#119)
- `blocked-ac` GitHub label (`#B60205`): AC quality gate failed under skill-fix. (#119)

### Changed
- `skills/discover/SKILL.md`: AUTOPILOT-GUARD and HARD-GATE extended to accept `--skill-fix` flag in addition to `--autopilot`. **HARD-GATE contract change**: discover skill に `--skill-fix` flag を追加。skill-fix subagent 経由の inline plan mode をサポート（HARD-GATE 契約変更）。Step 7 adds `--skill-fix` mode (user approval skipped, quality gates retained). Persona auto-select condition updated to `(--autopilot OR --skill-fix) AND valid_persona_count == 0`. `plan` SKILL.md remains unchanged — HARD-GATE fully maintained (see AC10). (#119)
- `commands/setup-github.md`: `blocked-ac` label added to the standard label set for new projects (prevents drift). (#119)

### HARD-GATE Compensation (discover --skill-fix)
1. Scope: discover only, plan HARD-GATE unchanged (AC10)
2. Audit trail: `<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #N at <ISO-8601> -->` in every skill-fix-created Issue
3. Quality gates retained: MUST-1/2/3 + UX U1-U5 + Interruption I1-I4 execute under `--skill-fix`
4. BLOCKED termination: gate FAIL → `blocked-ac` label, no `ready-to-go`
5. CHANGELOG: this entry

### BREAKING Changes (inherited from 2.0.0 — still in effect)
- `--light` and `--heavy` flags removed (see [2.0.0] for full migration guide). Use `spawn_profiles.custom` in `.claude/config.yml` or `--profile="..."`. (#122)

---

### Added (Japanese / 日本語)
- `skills/skill-fix/SKILL.md`: セッション中に atdd-kit skill の不具合を発見した際、対応中 issue を中断せず background subagent で `ready-to-go` まで自動起票するフロー。明示コマンド `/atdd-kit:skill-fix` と暗黙起動（skill 名 × 意向動詞）の 2 パターン。3 問 interview → duplicate check → subagent dispatch（`isolation: worktree` + `run_in_background: true`）。(#119)
- `commands/skill-fix.md`, `lib/skill_fix_dispatch.sh`, `docs/workflow/skill-fix-flow.md`, `templates/workflow/blocked_ac_comment.md`: 関連ファイル一式。(#119)
- 10 本の bats テスト（AC1-AC10 カバレッジ）。(#119)
- `blocked-ac` GitHub ラベル（`#B60205`）。(#119)

### Changed (Japanese / 日本語)
- `skills/discover/SKILL.md`: AUTOPILOT-GUARD / HARD-GATE 例外 / Step 7 の 3 箇所に `--skill-fix` 分岐を追加。**HARD-GATE 契約変更**: discover skill に `--skill-fix` flag を追加。skill-fix subagent 経由の inline plan mode をサポート。`plan` SKILL.md は変更なし（AC10 で CI 固定）。(#119)

## [2.0.1] - 2026-04-21

### Fixed
- `autopilot-worktree-guard`: hook now auto-detects worktree boundary from stdin `cwd` when `ATDD_AUTOPILOT_WORKTREE` env var is unset, fixing the silent no-op caused by Claude Code's Bash tool not persisting shell state between invocations (fixes #116). The env var remains supported as an explicit override (precedence: env > cwd-detection > no-op); existing env-set behaviour is fully backward-compatible (patch bump). Non-autopilot session overhead increases by ~25ms per tool call (Python startup; negligible vs. 5s timeout). (#116)

### Changed
- `.claude/config.yml`: activate `spawn_profiles.custom` — five roles (`developer` / `qa` / `tester` / `researcher` / `writer`) pinned to `sonnet` and `reviewer` pinned to `opus` for deeper review quality. Flagless `/atdd-kit:autopilot` runs on this repo now use this matrix. `--profile="..."` overrides are unaffected. (#128)

## [2.0.0] - 2026-04-20

### BREAKING Changes
- Autopilot spawn profile UX simplified from 3 paths (`--light` / `--heavy` / `--profile=NL`) to 2 paths: **default** (flagless) and `--profile="NL"`. Passing `--light` or `--heavy` now halts with `Unknown flag: --light (removed in BREAKING change; use --profile="..." instead. supported: --profile)` (substitute `--heavy` as appropriate). Replace preset usage by defining `spawn_profiles.custom` in `.claude/config.yml` for sticky defaults, and/or `--profile="..."` for one-off overrides. (#122)
- Configuration files merged into a single source of truth: the plugin-side `config/spawn-profiles.yml` and the project-side `.claude/workflow-config.yml` are gone. All spawn profile + platform settings now live in **`.claude/config.yml`**. `skills/session-start` auto-migrates existing projects on the next session (write-then-delete, idempotent); new projects get `.claude/config.yml` with a `spawn_profiles.custom` placeholder template. (#122)
- Positional NL after the issue number is no longer a supported invocation path. Use `--profile="..."` exclusively for NL profile overrides. (#122)
- `Profile Confirmation Gate` now fires **only** when `--profile` is supplied; flagless runs (including those that auto-apply `spawn_profiles.custom`) skip the gate. (#122)

### Added
- `lib/spec_check.sh`: 7 subcommands (`derive_slug`, `spec_exists`, `read_acs`, `spec_status`, `spec_persona`, `get_spec_load_message`, `get_spec_warn_message`) — single source of truth for spec file detection and slug derivation, mirroring the `lib/persona_check.sh` dispatcher pattern. `GH_CMD_OVERRIDE` and `SPEC_SLUG_OVERRIDE` env vars enable JA titles and testability. (#70)
- `rules/atdd-kit.md`: Iron Law 4 mandating atdd/verify/bug to load `docs/specs/<slug>.md` via `lib/spec_check.sh` before implementation or AC judgement. File stays at the 40-line cap. (#70)
- `skills/atdd/SKILL.md` "Spec Load (after State Gate PASS, before first AC)": persona-check → spec-check ordering; emits `Loaded docs/specs/<slug>.md (AC count: N)`. (#70)
- `skills/verify/SKILL.md` "Spec Authority Check": status tiebreak (approved/implemented → spec wins; draft/deprecated → Issue comments win with `[spec-warn]` prefix). (#70)
- `skills/bug/SKILL.md` "Spec Citation in Root Cause Classification": spec present → cite governing AC; absent → Classification A with `no spec found for <area>`. (#70)
- `docs/methodology/us-ac-format.md`: "Slug Derivation Rule" (1 Issue = 1 spec, EN-only + JA override), "Spec ↔ Issue Divergence Matrix" (5 patterns + status tiebreak) with cross-link to Rename Run-Book. (#70)
- `docs/guides/spec-reference.md`: full reference for the AC6 fallback matrix and the shared Spec Reference flow across atdd/verify/bug. (#70)
- `docs/specs/llm-us-ac-auto-reference.md`: self-dogfooded spec for #70 itself (AC7). (#70)
- `skills/{atdd,verify,bug}/evals/evals.json`: new spec-reference behavioral evals — atdd +4 (spec-load + 3 fallback variants), verify +8 (3 tiebreak + 5 drift matrix), bug +2 (classification-cites-spec / reports-missing). (#70)
- `tests/test_spec_check.bats` (15 @test) and `tests/test_spec_reference.bats` (22 @test): structural coverage of helper exports, slug rule, rules invariant, Divergence Matrix, and EN-only reference convention. (#70)
- `evals/footprint/spec-reference.yml` + `evals/footprint/baseline.json` update: new 3-SKILL footprint checkpoint (covers bug SKILL.md which is not on the autopilot path); autopilot delta +496 ≤ +500 token budget. (#70)
- `config/spawn-profiles.yml`: single source of truth for autopilot spawn profiles. `profiles.light.*` maps every sub-agent role to `sonnet`; `profiles.heavy.*` maps every sub-agent role to `opus`. (#109)
- `commands/autopilot.md` Phase 0 Argument Parsing sub-heading: parses `--light` / `--heavy` / `--profile=<text>` / `--profile <text>` / trailing positional NL. Position-independent. Halts before Phase 0.9 on unknown flag, conflicting preset flags, utility-mode misuse, search-mode NL violation, preset+NL mixing, or double NL sources. (#109)
- `commands/autopilot.md` Profile Confirmation Gate (fires before Phase 0.9 whenever a profile flag is supplied): prints the 6-role resolved matrix and confirms via AskUserQuestion, with a text-input `Reply with 1 (apply) or 2 (cancel).` fallback. No Team / worktree is created until the user approves. Main Claude (orchestrator) is not listed because its model is never overridden by these flags. (#109)
- `commands/autopilot.md` Agent spawn model resolution rule: each spawn site in AC Review Round, Phase 3 (Developer / Tester / Researcher / Writer), and Phase 4 (Reviewer) references the resolved matrix for the `model` parameter passed to the Agent tool. When no flag is supplied, the parameter is omitted so sub-agents inherit their session default. Mid-phase resume spawns pick up the current invocation's profile. (#109)
- `commands/autopilot.md` NL Resolution Examples block (marked with `<!-- nl-example start/end -->`): documents three representative per-role resolutions for positional NL, `--profile=` delimiter, and space-delimiter forms. (#109)
- `docs/tests/nl-profile-fixtures.md`: 10 manual-verify fixtures pinning expected resolved matrices for preset flags, positional NL, and `--profile` variants. PR merge DoD references these fixtures for human smoke-test evidence. (#109)
- `tests/test_spawn_profiles_config.bats`, `tests/test_autopilot_profile_parsing.bats`, `tests/test_autopilot_profile_flags.bats`, `tests/test_autopilot_nl_profile.bats`, `tests/test_autopilot_profile_main_claude_isolation.bats`: 61 drift-detect cases covering AC1–AC20 including code-fence-aware main-Claude isolation (AC3) and nl-example-aware single-source-of-truth (AC8). (#109)

### Scope Note — effort control not supported (#109)
`effortLevel` is **not** controlled by any profile flag in this release. Investigation during plan (#109) revealed that the Claude Code Agent tool schema does not expose an `effortLevel` parameter per-spawn; only `model` is overridable. Accordingly, `--light` / `--heavy` override the spawn `model` only (`sonnet` / `opus`), and NL profile grammar rejects any effort-dimension tokens with the `Effort control is not supported in this release.` error. Follow-up work to add effort control will be filed as a separate Issue once the Agent tool gains the parameter.

### Model version note (#109)
`model: opus` resolves to whichever Opus revision the Claude Code session is configured to run. The enum is not version-pinned; spawn-side Opus may therefore differ from main Claude's Opus revision at run time. This is deliberate — the profile matrix is intentionally decoupled from specific model revisions.

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

