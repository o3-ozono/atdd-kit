> **Loaded by:** running-atdd-cycle / reviewing-deliverables / merging-and-deploying skills

# Test Execution Policy

This document defines **when** and **which scope** of tests to run at each phase of the atdd-kit workflow.
It is a policy doctrine for test execution scope — not a test-layer mapping.
For AC-to-test-layer mapping, see [test-mapping.md](test-mapping.md).

## Core Doctrine: Phase x Impact

Test execution scope is determined by two axes: **what was modified (impact)** and **which phase you are in**.
The physical location of a test file (local-only, CI-only) is not the deciding factor.

| Phase | Scope | Rationale |
|-------|-------|-----------|
| Each ATDD iteration | **Affected files only** (`scripts/run-tests.sh --impact --base <ref>`) | Keeps the feedback loop short. Tests unrelated to the change are not run on every iteration. |
| Before final user review | **All tests** (`scripts/run-tests.sh --all`) | Ensures full regression coverage before review judgment. |
| Merge gate | **All tests** (`scripts/run-tests.sh --all` + CI full suite) | Guarantees full-suite green before merging. |

## Handling claude-based e2e Tests

`tests/e2e/*.bats` and similar live-LLM tests were historically gated by physical location (local-only or CI-only).
Under this doctrine they are integrated into the impact-based criteria:

- **Decision criterion:** whether the change touches the skill or code the e2e test covers (impact), not where the test file lives.
- If an iteration modifies a skill's core logic → include the relevant e2e in the impact scope.
- If an iteration does not touch the skill's core → the e2e is out of scope and may be skipped.

## Live e2e Execution Condition Inventory

The table below maps currently skip-guarded or CI-only live e2e tests to their impact-based equivalents.

| Test group | Previous condition (physical) | Impact-based condition |
|------------|-------------------------------|------------------------|
| `tests/e2e/*.bats` (live LLM e2e) | skip guard / dedicated CI workflow — local or CI only | Include in impact scope only when the change touches the tested skill or component |

## Platform-Agnostic Application

This policy applies to **all platforms** supported by atdd-kit: `other` (bats/@covers), `web` (jest/vitest), and `iOS` (XCTest). The `--platform` flag on `scripts/impact_map.sh` selects the adapter; the phase-based scoping rule is the same regardless of platform.

| Platform | Impact-scope command | Full-suite command |
|----------|---------------------|--------------------|
| other (bats) | `scripts/impact_map.sh --platform other --base <ref> --layer BATS` | `scripts/run-tests.sh --all` |
| web (jest/vitest) | `scripts/impact_map.sh --platform web --config config/impact_rules.yml --base <ref> --layer skill-e2e` | `scripts/run-tests.sh --all` |
| iOS (XCTest) | `scripts/impact_map.sh --platform ios --config config/impact_rules.yml --base <ref> --layer skill-e2e` | `scripts/run-tests.sh --all` |

The generalization and distribution of the impact-selection tool was completed in Issue #323. The impact runner (`scripts/impact_map.sh`) and platform-specific rule templates (`addons/web/config/impact_rules.yml`, `addons/ios/config/impact_rules.yml`) are deployed to consumer projects via `setup-web` / `setup-ios`.

## Position as a Distributed Methodology

This policy (all tests before final review / impact-only during each ATDD iteration) is the **standard doctrine**
distributed to every project that adopts atdd-kit. It is a methodology artifact, not a project-specific configuration.

**Related doctrine:** [acceptance-test-feasibility.md](acceptance-test-feasibility.md) governs which ATs are executable in the first place (feasibility probe at Step 3). This execution policy governs *when* to run those ATs once they are confirmed feasible and marked `[planned]`.
