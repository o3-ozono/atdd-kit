#!/usr/bin/env bats
# @covers: docs/workflow/workflow-detail.md
# Issue #269: Align workflow-detail.md review description with #234 dynamic parallel Workflow panel
#
# AT lifecycle: draft -> green -> regression
# Current state: [regression]

# AT-001: Execution Mode section conveys current architecture (US-1)
#
# Given: docs/workflow/workflow-detail.md Execution Mode section
# When:  Review step bullet is inspected (grep for serially / specialist reviewer subagents)
# Then:  Legacy "serially spawn specialist reviewer subagents" description is absent;
#        dynamic panel (dynamically), parallel execution (in parallel), adversarial verification,
#        and Aggregate PASS/FAIL + per-lens notes are present

@test "#269 AT-001: 'serially' is absent from Execution Mode section" {
  ! grep -q 'serially' docs/workflow/workflow-detail.md
}

@test "#269 AT-001: 'specialist reviewer subagents' is absent from workflow-detail.md" {
  ! grep -q 'specialist reviewer subagents' docs/workflow/workflow-detail.md
}

@test "#269 AT-001: 'dynamically' is present in workflow-detail.md" {
  grep -q 'dynamically' docs/workflow/workflow-detail.md
}

@test "#269 AT-001: 'in parallel' is present in workflow-detail.md" {
  grep -q 'in parallel' docs/workflow/workflow-detail.md
}

@test "#269 AT-001: 'Aggregate' is present in workflow-detail.md" {
  grep -q 'Aggregate' docs/workflow/workflow-detail.md
}

@test "#269 AT-001: 'adversarially verified' is present in workflow-detail.md" {
  grep -q 'adversarially verified' docs/workflow/workflow-detail.md
}

@test "#269 AT-001: 'PASS/FAIL' is present in workflow-detail.md" {
  grep -q 'PASS/FAIL' docs/workflow/workflow-detail.md
}

@test "#269 AT-001: 'per-lens notes' is present in workflow-detail.md" {
  grep -q 'per-lens notes' docs/workflow/workflow-detail.md
}

# AT-002: Review Workflow section mermaid diagram depicts current phase structure (US-2)
#
# Given: docs/workflow/workflow-detail.md former Reviewer Aggregation Flow section
# When:  Section intro and mermaid diagram are inspected
# Then:  Fixed 5-reviewer nodes (prd/us/plan/code/at) and final-reviewer/aggregate-47-criteria absent;
#        Scout / Generate / Review (parallel) / Verify (adversarial) / Aggregate nodes present;
#        PASS -> ready-to-go / FAIL -> needs-plan-revision branches present

@test "#269 AT-002: 'prd-reviewer' is absent from workflow-detail.md" {
  ! grep -q 'prd-reviewer' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'us-reviewer' is absent from workflow-detail.md" {
  ! grep -q 'us-reviewer' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'plan-reviewer' is absent from workflow-detail.md" {
  ! grep -q 'plan-reviewer' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'code-reviewer' is absent from workflow-detail.md" {
  ! grep -q 'code-reviewer' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'at-reviewer' is absent from workflow-detail.md" {
  ! grep -q 'at-reviewer' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'final-reviewer' is absent from workflow-detail.md" {
  ! grep -q 'final-reviewer' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'aggregate 47 criteria' is absent from workflow-detail.md" {
  ! grep -qi 'aggregate 47 criteria' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'dispatches five specialist reviewers' is absent from workflow-detail.md" {
  ! grep -q 'dispatches five specialist reviewers' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'Scout' phase node is present in workflow-detail.md" {
  grep -q 'Scout' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'Generate' phase node is present in workflow-detail.md" {
  grep -q 'Generate' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'Verify' phase node is present in workflow-detail.md" {
  grep -q 'Verify' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'Verify (adversarial' qualifier is present in workflow-detail.md" {
  grep -qF 'Verify (adversarial' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'ready-to-go' branch is present in mermaid diagram" {
  grep -q 'ready-to-go' docs/workflow/workflow-detail.md
}

@test "#269 AT-002: 'needs-plan-revision' branch is present in mermaid diagram" {
  grep -q 'needs-plan-revision' docs/workflow/workflow-detail.md
}

# AT-003: No legacy descriptions remain anywhere in the document (US-3)
#
# Given: Full text of replaced docs/workflow/workflow-detail.md
# When:  Legacy vocabulary is searched (grep -inE 'serial|specialist reviewer|47 criteria|aggregator')
# Then:  Zero hits; replaced description consistent with skills/reviewing-deliverables/SKILL.md

@test "#269 AT-003: no 'serial' word (case-insensitive) in workflow-detail.md" {
  ! grep -qiw 'serial' docs/workflow/workflow-detail.md
}

@test "#269 AT-003: no 'specialist reviewer' phrase in workflow-detail.md" {
  ! grep -qi 'specialist reviewer' docs/workflow/workflow-detail.md
}

@test "#269 AT-003: no '47 criteria' phrase in workflow-detail.md" {
  ! grep -qi '47 criteria' docs/workflow/workflow-detail.md
}

@test "#269 AT-003: no 'aggregator' word in workflow-detail.md" {
  ! grep -qiw 'aggregator' docs/workflow/workflow-detail.md
}

@test "#269 AT-003: heading '## Reviewer Aggregation Flow' is absent" {
  ! grep -q '## Reviewer Aggregation Flow' docs/workflow/workflow-detail.md
}

@test "#269 AT-003: heading '## Review Workflow Flow' is present" {
  grep -q '## Review Workflow Flow' docs/workflow/workflow-detail.md
}

# AT-004: Release discipline — CHANGELOG entry + patch version bump (CS-1)
#
# Given: PR #270 diff including this Issue's changes
# When:  CHANGELOG.md and .claude-plugin/plugin.json are inspected
# Then:  CHANGELOG.md has [3.11.2] ### Fixed entry referencing #269;
#        plugin.json stays consistent with the topmost CHANGELOG release
#
# #272 hardening: the original literal pin (`version is 3.11.2`) false-failed on
# the very next version bump — a regression test must hold on any future branch,
# so the plugin.json assertion is the CHANGELOG-consistency invariant instead.

@test "#269 AT-004: CHANGELOG.md has 3.11.2 entry" {
  grep -q '3\.11\.2' CHANGELOG.md
}

@test "#269 AT-004: CHANGELOG.md 3.11.2 entry references #269" {
  grep -A5 '3\.11\.2' CHANGELOG.md | grep -q '269'
}

@test "#269 AT-004: plugin.json version matches the topmost CHANGELOG release" {
  top=$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | tr -d '#[] ')
  [ -n "$top" ]
  grep '"version"' .claude-plugin/plugin.json | grep -qF "\"$top\""
}

# AT-005: Change scope limited to documentation side (CS-2)
#
# The original AT-005 asserted `git diff main` scope (allowlist + denylist).
# That guarantee was one-time by nature — it verified PR #270's scope and was
# satisfied at merge; on any LATER branch (e.g. #272 touching lib/, #271
# touching agents/) the same asserts false-fail, blocking unrelated AT gates.
# Removed as executable regression (#272); the one-time verification remains
# recorded in docs/issues/269-*/acceptance-tests.md and PR #270.
