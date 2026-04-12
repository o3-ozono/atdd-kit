# Tests

All tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Tests validate plugin behavior including skill structure, label flows, script functionality, and configuration integrity.

## Running Tests

```bash
bats tests/                      # Run core tests
bats addons/ios/tests/           # Run iOS addon tests
bats tests/ addons/ios/tests/    # Run all tests
```

## Core Test Files

| Test File | Target |
|-----------|--------|
| test_agent_teams.bats | Agent Teams architecture validation |
| test_autopilot_agent_teams_setup.bats | autopilot Agent Teams enforcement |
| test_autopilot_args.bats | autopilot argument parsing |
| test_autopilot_review_gate.bats | autopilot Phase 5 review PASS verification |
| test_autonomy_levels.bats | Autonomy level label and gate behavior |
| test_bilingual_templates.bats | Bilingual template (en/ja) validation |
| test_changelog_format.bats | CHANGELOG.md format compliance |
| test_check_plugin_version.bats | Plugin version check script |
| test_conflict_detection.bats | Git conflict detection logic |
| test_context_block.bats | Context block generation |
| test_discover_approach_parity.bats | discover equal-detail rule |
| test_discover_autopilot_approval.bats | discover autopilot approval flow |
| test_doc_agent_teams_sync.bats | Documentation and Agent Teams sync |
| test_eval_framework.bats | Skill eval framework |
| test_gate_integration.bats | Skill gate integration |
| test_global_content_migration.bats | Global content migration validation |
| test_i18n_language_resolution.bats | Language resolution removal verification |
| test_i18n_translation.bats | Language policy enforcement (English-only LLM files) |
| test_interaction_reduction.bats | Interaction reduction validation |
| test_label_flow.bats | Issue/PR label state transitions |
| test_notification_removal.bats | Notification removal verification |
| test_po_dev_qa.bats | Agent role definitions (agents/*.md) |
| test_public_repo_prep.bats | Public repository preparation checks |
| test_session_start_adapters.bats | Session start adapter removal verification |
| test_session_start_agent_teams_env.bats | Session start Agent Teams env auto-configuration |
| test_session_start_auto_sync.bats | Addon-based file sync |
| test_session_start_recent_activity.bats | Session start recent activity detection |
| test_session_start_task_recommendation.bats | Session start task recommendation |
| test_session_start_version.bats | Session start version check |
| test_ship_review_gate.bats | ship skill review gate |
| test_skill_adapters.bats | Agent skill preloading (agents/*.md frontmatter) |
| test_skill_staleness.bats | Skill staleness detection |
| test_skill_structure.bats | Skill directory structure validation |
| test_template_sync.bats | Template and .github/ copy sync verification |
| test_state_gates.bats | State Gate enforcement |
| test_ui_test_debugging.bats | UI test debugging skill validation |
| test_weekly_maintenance_removal.bats | Weekly maintenance removal verification |
| test_workflow_config_fields.bats | workflow-config.yml platform-only validation |
| test_worktree_isolation.bats | Worktree isolation validation |
| test_task_type_labels.bats | Task type label migration (investigation→research) |
| test_ready_to_go.bats | ready-to-go label migration validation |
| test_autopilot_guard_block.bats | Autopilot-only STOP guard enforcement |
| test_task_type_workflow.bats | Task-type-specific workflow branching |
| test_legacy_terms.bats | Legacy term elimination verification |

## iOS Addon Tests (addons/ios/tests/)

| Test File | Target |
|-----------|--------|
| test_sim_ephemeral_clone.bats | Ephemeral clone lifecycle |
| test_sim_golden_init.bats | Golden image lazy initialization |
| test_sim_failclosed_guard.bats | Fail-closed guard |
| test_sim_persist_block.bats | persist: true blocking |
| test_sim_auto_inject.bats | Auto-injection |
| test_sim_orphan_cleanup.bats | Orphan clone cleanup |
| test_sim_golden_set_fallback.bats | Golden Device Set isolation |
| test_sim_init_guidance.bats | Addon guidance validation |
| test_sim_pool_docs.bats | sim-pool documentation |

## Conventions

- File naming: `test_<target>.bats`
- Each test file focuses on one feature or module
- Tests must pass with zero external dependencies (no network, no npm)
- iOS addon tests live in `addons/ios/tests/`, not in `tests/`

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Zero dependencies policy
- [BATS documentation](https://bats-core.readthedocs.io/)
