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
#        plugin.json version is 3.11.2

@test "#269 AT-004: CHANGELOG.md has 3.11.2 entry" {
  grep -q '3\.11\.2' CHANGELOG.md
}

@test "#269 AT-004: CHANGELOG.md 3.11.2 entry references #269" {
  grep -A5 '3\.11\.2' CHANGELOG.md | grep -q '269'
}

@test "#269 AT-004: plugin.json version is 3.11.2" {
  grep '"version"' .claude-plugin/plugin.json | grep -q '3\.11\.2'
}

# AT-005: Change scope limited to documentation side (CS-2)
#
# Given: Diff between working branch and main
# When:  Changed file list is inspected (git diff main --name-only)
# Then:  skills/reviewing-deliverables/SKILL.md and agents/ directory unchanged

@test "#269 AT-005: skills/reviewing-deliverables/SKILL.md is not changed vs main" {
  ! git diff main --name-only | grep -q 'skills/reviewing-deliverables/SKILL\.md'
}

@test "#269 AT-005: agents/ directory files are not changed vs main" {
  ! git diff main --name-only | grep -q '^agents/'
}
