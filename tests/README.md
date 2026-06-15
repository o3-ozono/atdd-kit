# Tests

All tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Tests validate plugin behavior including skill structure, label flows, script functionality, and configuration integrity.

## Running Tests

```bash
bats tests/                      # Run core tests
bats addons/ios/tests/           # Run iOS addon tests
bats tests/ addons/ios/tests/    # Run all tests
```

### Impact-Scoped Execution (fast feedback)

Run only the BATS files affected by your current changes:

```bash
# Run only tests covering files changed since origin/main
scripts/bats_runner.sh --impact --base origin/main

# Run all tests (same as bats tests/ addons/ios/tests/)
scripts/bats_runner.sh --all
```

Requires `scripts/impact_map.sh` (introduced in #135) and `@covers:` annotations in BATS headers.

Validate that all BATS files have annotations:

```bash
scripts/check_bats_covers.sh   # exits 0 with "OK: N files" if all annotated
```

## Core Test Files

### v1.0 Skill Tests (6-step flow)

Structural unit tests for each step's skill. One `@test` per User Story.

| Test File | Target |
|-----------|--------|
| test_defining_requirements_skill.bats | defining-requirements skill (Step 1, produces PRD) — Draft-PR-based presentation (#267: write draft → commit/push/Draft PR → approval gate order; PR link + decision points only, mode-independent) |
| test_extracting_user_stories_skill.bats | extracting-user-stories skill (Step 2) |
| test_writing_plan_and_tests_skill.bats | writing-plan-and-tests skill (Step 3, plan + acceptance tests) |
| test_running_atdd_cycle_skill.bats | running-atdd-cycle skill (Step 4, ATDD double loop) |
| test_reviewing_deliverables_skill.bats | reviewing-deliverables skill (Step 5) |
| test_merging_and_deploying_skill.bats | merging-and-deploying skill (Step 6) |
| test_launching_preview_skill.bats | launching-preview skill (on-demand, Step B7 / #194) |
| test_writing_design_doc_skill.bats | writing-design-doc skill (on-demand, Step B8 / #195) |
| test_bug_skill.bats | bug skill (special flow, Step C1 / #196) |
| test_debugging_skill.bats | debugging skill (special flow, Step C1 / #196) |
| test_express_skill.bats | express skill (documentation-grade fast path, Issue #284) |
| test_skill_test_coverage.bats | all 10 flow skills have both Unit Test + Skill E2E Test (Step C1 / #196); and all E2E files specify `--model` + define `E2E_MODEL` (#278) |
| test_v1_skill_skeletons.bats | v1.0 skill structure across all 6 steps + on-demand skills (skeleton set now empty) |
| test_agents_dynamic_panel_align.bats | Fixed reviewer agents removal and #234 alignment regression pins (Issue #271) |

### autopilot — autopilot (#246)

Tests for the autopilot orchestrator and its convergence safety rails.

| Test File | Target |
|-----------|--------|
| test_autopilot_skill.bats | autopilot skill (autopilot orchestrator) — oracle / rails / three User gates (requirements, design approval, merge) / iron-law wiring / args contract (#256: fail-closed phase guard, no impl→design fallback) / dialog economy (#254: human-only questions, batch-present) / log-integrity plumbing (#262: logLines baseline + recorded counter + 'log-integrity' halt) / design-gate rejection plumbing (#261: `rejectionFindings` validation + iteration-1 seed, whole-set rejection discipline) / model assignment (#259: impl subagents Sonnet, one-way escalation, design phase excluded) / presentation channel (#267: Gate ①/② deliverable bodies as the Draft PR diff, terminal = PR link + decision points only, full-channel sync kept) / step-scoped sameness+stuck + oracle-state fingerprint (#272: AT-005 rails passes ${step} to check_sameness/check_stuck, AT-006 audit payload = JSON.stringify({ atGreen, coverageOk, uncovered, blocking })) / diff-in-body (#275: boundary canary AT-000 guards the sed section headings against silent EOF expansion, re-presentation per-finding diff hunks + key lines, first-presentation key decisions with file/line refs, hand-off per-file stat + key hunks, operational definitions pinned, #267/#275 reconciliation pinned in both sections, ban polarity anchored, empty rejectionFindings refused fail-closed) |
| test_autopilot_convergence.bats | lib/autopilot_convergence.sh safety rails (behavioral: fingerprint / JSONL audit / sameness / stuck / max-iterations / log-integrity (#262: exact line-count match, fail-closed)) / step-scoped sameness+stuck (#272: AT-001 cross-step false-halt fix, AT-002 same-step halt preserved, AT-003 backward compat, AT-004a/b/c check_stuck step filter) / FAIL-only population (#277: AT-001 false-stuck-halt repro, AT-002 PASS-row exclusion from sameness, AT-003 legacy-mode FAIL-only, AT-004 detection-power maintained, AT-006 cross-run FAIL adjacency semantics pin — 49 tests total) |
| e2e/autopilot.bats | autopilot Skill E2E Test（#275: US-1 ゲート再提示の diff-in-body 回復を含む） |

### Skill Structure & Quality

| Test File | Target |
|-----------|--------|
| test_skill_structure.bats | Skill directory structure validation |
| test_skill_staleness.bats | Skill staleness detection for SKILL.md files |
| test_skill_description_lint.bats | Skill description anti-pattern linter |
| test_skill_adapters.bats | Agent skill preloading (agents/*.md frontmatter) |
| test_session_start_adapters.bats | Session-start skill-adapter removal verification |
| test_tightening_protection.bats | Structural elements survive English compression (Issue #78) |
| test_ui_test_debugging.bats | ui-test-debugging skill validation |

### skill-fix

| Test File | Target |
|-----------|--------|
| test_skill_fix_structure.bats | skill-fix SKILL.md structure — explicit trigger, interview Q count, 1-line report (Issue #119) |
| test_skill_fix_dispatch.bats | lib/skill_fix_dispatch.sh — 4-class fixtures, RED/GREEN fixtures, inflight registry, cleanup (Issue #119) |
| test_skill_fix_beta_dispatch.bats | lib/skill_fix_dispatch.sh β strategy — build_subagent_prompt, Skill tool chain, env (Issue #119) |
| test_skill_fix_isolation.bats | skill-fix worktree isolation + guard false-fire prevention (Issue #119) |
| test_skill_fix_skill_md.bats | skill-fix SKILL.md drift check + static asserts (Issue #119) |
| test_skill_fix_env_contract.bats | 3-env inheritance contract (GH_TOKEN + AGENT_TEAMS inherited, Issue #119) |
| test_skill_fix_blocked_ac.bats | skill-fix blocked-ac gate flow when quality gates fail (Issue #119) |
| test_skill_fix_audit_marker.bats | skill-fix audit marker regex pinning (Issue #119) |

### Session Start

| Test File | Target |
|-----------|--------|
| test_session_start_agent_teams_env.bats | session-start Agent Teams env auto-configuration |
| test_session_start_auto_sync.bats | session-start addon-based file sync |
| test_session_start_recent_activity.bats | session-start Recent Activity (24h) reporting |
| test_session_start_task_recommendation.bats | session-start task recommendation (in-progress Issue handling) |
| test_session_start_version.bats | session-start version check — SKILL.md Phase 1-E parses RESTART_REQUIRED + restart message in Phase 3 report (AT-005: 2 cases) + SKILL.md Phase 1-E parses STALE_SESSION + restart message + E2 Auto-Sync skip wiring (AT-003: 3 cases) (#280) |
| test_conflict_detection.bats | session-start git conflict detection |

### Spec / US / AC Mechanism

| Test File | Target |
|-----------|--------|
| test_spec_check.bats | lib/spec_check.sh — spec detection + slug derivation (Issue #70) |
| test_spec_reference.bats | LLM US/AC auto-reference structural tests (Issue #70) |
| test_us_ac_format.bats | docs/specs/ introduction and US/AC format (Issue #66) |
| test_us_quality_standard.bats | User Story quality standard (Issue #68) |
| test_skill_status_spec.bats | SKILL_STATUS spec document (Issue #58) |
| test_context_block.bats | Context Block information handoff between skills |

### Labels & Workflow

| Test File | Target |
|-----------|--------|
| test_label_flow.bats | Issue/PR label state transitions |
| test_ready_to_go.bats | ready-to-go label migration (replacing the old label) |
| test_task_type_labels.bats | Task type label consolidation (investigation → research) |
| test_legacy_terms.bats | Legacy term elimination verification |
| test_skill_terminology_grep.bats | Legacy skill-testing terminology must not appear in active source (#222) |
| test_rules_workflow.bats | rules/atdd-kit.md workflow invariants (Issue #187) |
| test_question_design_migration.bats | Question design migration |

### Headless Skill-Chain Replay (see [docs/guides/headless-skill-testing.md](../docs/guides/headless-skill-testing.md))

| Test File | Target |
|-----------|--------|
| test_skill_transcript_parser.bats | lib/skill_transcript_parser.sh — stream-json Skill event parser (Issue #72) |
| test_skill_assertion.bats | lib/skill_assertion.sh — subsequence/strict/forbidden match model (Issue #72) |
| test_headless_runner.bats | scripts/test-skills-headless.sh replay runner |
| test_headless_exit_codes.bats | Headless runner exit-code contract |
| test_pr_workflow_headless.bats | CI path-filter wiring for headless replay (Issue #72) |
| test_pr_workflow_skill_e2e.bats | CI skill-e2e-test job (dry-run) + skill-e2e-live.yml wiring (Step G1 / #208) |
| test_skill_e2e_subscription_workflow.bats | skill-e2e-subscription.yml の課金方針・信頼境界 invariants（env 化 / 課金 env 全弾き / main ref 限定 / SHA pin / no-op）(#243) |

### Hooks & Scripts

| Test File | Target |
|-----------|--------|
| test_main_branch_guard.bats | main-branch-guard PreToolUse hook (Issue #38 / #181 / #251) |
| test_bash_output_normalizer.bats | Bash PostToolUse output normalizer (Issue #85) |
| test_hook_distribution.bats | PostToolUse hook plugin distribution (Issue #85) |
| test_token_measurement_tooling.bats | Token reduction measurement tooling (Issue #85) |
| test_bats_runner.bats | scripts/bats_runner.sh impact-scoped runner |
| test_check_bats_covers.bats | scripts/check_bats_covers.sh annotation validator |
| test_impact_map.bats | scripts/impact_map.sh impact scope detection (Issue #135) |
| test_run_skill_e2e_impact.bats | scripts/run-skill-e2e.sh path-based impact mapping (Issue #222) |
| test_skill_gate_collision.bats | scripts/check-issue-collision.sh + skill-gate parallel collision detection (Step C2 / #197) |
| test_check_plugin_version.bats | scripts/check-plugin-version.sh — legacy tokens (FIRST_RUN/NO_UPDATE/UPDATED/VERSIONS/BREAKING) + STALE_SESSION (AT-002: loaded < cached, marker unchanged) + RESTART_REQUIRED (AT-001: installed > loaded, marker unchanged) + simultaneous-condition priority STALE wins (AT-007) + fallback when installed_plugins.json absent/unparseable/no-matching-entry (AT-006: 5 cases) + CHANGELOG guard VERSIONS:UNKNOWN when cached heading absent (AT-004: 2 cases) + post-restart recovery to UPDATED/NO_UPDATE (AT-008: 2 cases) + network-independence static inspection (AT-009: 2 cases) (#280) |

### Templates, Docs & Config

| Test File | Target |
|-----------|--------|
| test_bilingual_templates.bats | Bilingual issue template validation |
| test_docs_issues_templates.bats | docs/issues/ per-Issue templates (prd.md headings, etc.) |
| test_template_sync.bats | templates/ and .github/ copy sync verification |
| test_changelog_format.bats | CHANGELOG.md format compliance |
| test_docs_restructure.bats | docs/ directory restructure (Issue #64) — Draft-PR-based deliverable rule in workflow-detail.md (#267) — review description aligned to dynamic parallel Workflow panel (#269: AT-001/002/003) |
| test_doc_agent_teams_sync.bats | Documentation / Agent Teams doc sync (Issue #146) |
| test_gh_field_audit.bats | docs gh --json usage audit (Issue #85) |
| test_workflow_config_fields.bats | workflow-config.yml platform-only validation |
| test_i18n_translation.bats | Language policy (English-only LLM files, bilingual user docs) |
| test_i18n_language_resolution.bats | Language resolution removal verification |

### Migrations & Removals (regression guards)

| Test File | Target |
|-----------|--------|
| test_global_content_migration.bats | Global config → atdd-kit content migration (Issue #51) |
| test_notification_removal.bats | Notification integration removal (Issue #169) |
| test_weekly_maintenance_removal.bats | Weekly maintenance cron removal (Issue #155) |
| test_public_repo_prep.bats | Public repository preparation checks (Issue #16) |
| test_pr_screenshot_security.bats | pr-screenshot-table.sh security hardening (Issue #26) |
| test_conflict_detection.bats | Git conflict detection logic |
| test_issue_105_frontmatter_session_inheritance.bats | Agent frontmatter model/effort removal guard (Issue #105); updated by #271 to use glob-based detection instead of fixed 6-file list |
| test_phase_model_assignment.bats | Phase model assignment policy in agents/README.md — impl / review = Sonnet, escalation path, bench summary, design phase / orchestrator exclusion (Issue #259) |

> Some files cover more than one area; they are listed under their primary concern. The authoritative list is always `ls tests/*.bats`. Each file declares its scope via a `@covers:` header annotation (see below).

## Acceptance Tests (`tests/acceptance/`)

Per-Issue executable Acceptance Tests produced by the ATDD cycle (Step 4), named `AT-<NNN>.bats`. Each encodes the approved AC of `docs/issues/<NNN>-*/acceptance-tests.md` and stays as a regression suite after merge.

| Test File | Target |
|-----------|--------|
| AT-269.bats | workflow-detail.md review description aligned to the #234 dynamic parallel Workflow panel — legacy terms absent, current phase terms present, release discipline, doc-side change scope (Issue #269) |
| AT-271.bats | Fixed reviewer agents removal and #234 alignment regression pins — six fixed-reviewer agent files absent, agents/README.md dynamic panel wiring present (Issue #271) |
| AT-278.bats | Skill E2E tests specify --model sonnet for claude invocations — all E2E files pass --model flag, no unspecified invocations (Issue #278) |
| AT-284.bats | express skill re-introduction — documentation-grade fast path, SKILL.md/commands/express.md structure, skill-gate guard, CI gate (Issue #284) |
| AT-289.bats | AT-version-pin regression — CHANGELOG history-fact + latest-release-heading consistency assertions replace exact-version pins in AT-271/AT-284; helpers/changelog.bash shared helper; future-proof against version bumps (Issue #289) |

### Acceptance Test Helpers (`tests/acceptance/helpers/`)

共有ヘルパー関数ライブラリ。AT ファイルから `load` ディレクティブで読み込んで使用する。BATS の `load` は拡張子 `.bash` を自動補完する。

| ファイル | 提供関数 | 用途 |
|--------|---------|------|
| `changelog.bash` | `changelog_latest_release <path>` | `CHANGELOG.md` の `## [Unreleased]` を除いた先頭の `## [X.Y.Z]` からバージョン文字列を抽出する。バージョン完全一致ピンを避け、「CHANGELOG 最新リリース見出しとの整合」アサーションで AT を将来耐性化するために使用する（Issue #289）。 |

**使い方:**

```bash
# AT ファイルの setup() または @test 内で
load "$(dirname "$BATS_TEST_FILENAME")/helpers/changelog"

@test "plugin.json version matches CHANGELOG latest release" {
  local expected
  expected="$(changelog_latest_release "$ROOT/CHANGELOG.md")"
  local actual
  actual="$(jq -r .version "$ROOT/plugin.json")"
  [[ "$actual" == "$expected" ]]
}
```

## iOS Addon Tests (addons/ios/tests/)

| Test File | Target |
|-----------|--------|
| test_sim_ephemeral_clone.bats | Ephemeral clone lifecycle |
| test_sim_golden_init.bats | Golden image lazy initialization |
| test_sim_failopen_guard.bats | Fail-open guard |
| test_sim_persist_block.bats | persist: true blocking |
| test_sim_auto_inject.bats | Auto-injection |
| test_sim_orphan_cleanup.bats | Orphan clone cleanup |
| test_sim_golden_set_fallback.bats | Golden Device Set isolation |
| test_sim_init_guidance.bats | Addon guidance validation |
| test_sim_pool_docs.bats | sim-pool documentation |
| test_sim_clone_required_variants.bats | Clone-required device variants |
| test_sim_pattern_match.bats | Device pattern matching |

## Skill E2E Tests (`tests/e2e/`)

新フロー（#222 確定）の Skill E2E Test は `tests/e2e/<skill>.bats` 構造で、実 `claude` バイナリを起動して 1 User Story = 1 `@test` を回す。実行は `scripts/run-skill-e2e.sh` が path-based 影響範囲算定で対象を絞り込む。flow 対象 10 skill（6-step flow + on-demand 2: launching-preview / writing-design-doc + 特殊 2: bug / debugging）すべてに E2E が揃っており、`test_skill_test_coverage.bats` が Unit+E2E の揃いを機械検証する（#196）。

```bash
scripts/run-skill-e2e.sh --changed-files <list>   # 影響範囲分のみ
scripts/run-skill-e2e.sh --all                    # 全 skill
scripts/run-skill-e2e.sh --all --dry-run          # 対象解決のみ（実行なし）
```

ログは `tests/e2e/.logs/<run-id>.log` に出力される。詳細は [docs/testing-skills.md](../docs/testing-skills.md) を参照。

**実行モデル:** Skill E2E Test は `claude` 起動時にデフォルトで **sonnet** を使用する（#259 ベンチマーク準拠のコスト最適化）。別モデルで実行したい場合は `SKILL_E2E_MODEL` 環境変数で上書きできる（例: `SKILL_E2E_MODEL=claude-opus-4-5 scripts/run-skill-e2e.sh --all`）。

## Conventions

- File naming: `test_<target>.bats`
- Each test file focuses on one feature or module
- Tests must pass with zero external dependencies (no network, no npm)
- iOS addon tests live in `addons/ios/tests/`, not in `tests/`
- Skill E2E Tests (`tests/e2e/*.bats`) require a real `claude` binary in PATH (or `SKILL_TEST_CLAUDE_BIN` set); authentication is handled by `claude` CLI itself

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Zero dependencies policy
- [docs/testing-skills.md](../docs/testing-skills.md) — Unit Test / Skill E2E Test 2 層体系と cost baseline
- [BATS documentation](https://bats-core.readthedocs.io/)
