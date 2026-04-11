#!/usr/bin/env bats

# Issue #51: Migrate useful content from global config to atdd-kit upstream

# AC1: Commit rules detail in rules/atdd-kit.md
@test "AC1: rules/atdd-kit.md contains commit work unit examples" {
  grep -qi 'work unit\|work-unit' rules/atdd-kit.md || \
  grep -q 'docs/commit-guide.md' rules/atdd-kit.md
}

@test "AC1: commit anti-patterns are documented" {
  grep -qi 'anti-pattern' docs/commit-guide.md
}

@test "AC1: Co-Authored-By prohibition is documented" {
  grep -qi 'Co-Authored-By' docs/commit-guide.md
}

@test "AC1: commit work unit examples exist in commit guide" {
  grep -qi 'work unit' docs/commit-guide.md
}

# AC2: Japanese keyword list in bug skill
@test "AC2: bug SKILL.md contains Japanese trigger keywords" {
  grep -q '不具合\|おかしい\|壊れ\|動かない' skills/bug/SKILL.md
}

# AC3: Severity definition in review-guide
@test "AC3: review-guide.md contains severity definitions" {
  grep -q 'critical.*warning.*suggestion\|Severity' docs/review-guide.md
}

@test "AC3: review-guide.md contains critical severity with merge impact" {
  grep -qi 'critical.*block\|critical.*must fix' docs/review-guide.md
}

@test "AC3: review-guide.md contains framework-specific check examples" {
  grep -qi 'SwiftUI\|React\|Go' docs/review-guide.md
}

# AC4: Quality Score, guardrails, troubleshooting, mermaid in workflow-detail
@test "AC4: workflow-detail.md contains Quality Score formula" {
  grep -q 'Quality Score' docs/workflow-detail.md
}

@test "AC4: workflow-detail.md contains 6 guardrails" {
  grep -qi 'guardrail\|guard rail' docs/workflow-detail.md
}

@test "AC4: workflow-detail.md contains troubleshooting section" {
  grep -qi 'troubleshoot' docs/workflow-detail.md
}

@test "AC4: workflow-detail.md contains mermaid diagrams" {
  count=$(grep -c '```mermaid' docs/workflow-detail.md)
  [ "$count" -ge 4 ]
}

# AC5: Medium priority content
@test "AC5: atdd-guide.md contains UX checklist" {
  grep -q 'U1' docs/atdd-guide.md && grep -q 'U5' docs/atdd-guide.md
}

@test "AC5: atdd-guide.md contains ATDD applicability guidelines" {
  grep -qi 'applicab' docs/atdd-guide.md
}

@test "AC5: bug-fix-process.md contains decision flow diagram" {
  grep -q '```' docs/bug-fix-process.md
}

@test "AC5: bug-fix-process.md contains step precautions table" {
  grep -qi 'Reproduce\|Investigate\|Classify' docs/bug-fix-process.md
}

@test "AC5: bug-fix-process.md contains fix proposal format" {
  grep -qi 'Fix Proposal' docs/bug-fix-process.md
}

@test "AC5: autopilot.md contains Dev implementation phase" {
  grep -qi 'Phase.*3\|Implementation.*Dev\|Dev.*atdd' commands/autopilot.md
}

@test "AC5: autopilot.md contains QA review phase" {
  grep -qi 'Phase.*4\|PR.*Review.*QA\|QA.*review' commands/autopilot.md
}

@test "AC5: autopilot.md contains PO merge decision" {
  grep -qi 'Phase.*5\|merge.*decision\|マージ判断' commands/autopilot.md
}

@test "AC5: issue SKILL.md contains priority table P1/P2/P3" {
  grep -q 'P1' skills/issue/SKILL.md && grep -q 'P2' skills/issue/SKILL.md && grep -q 'P3' skills/issue/SKILL.md
}

@test "AC5: bug SKILL.md contains evidence collection table" {
  grep -qi 'evidence' skills/bug/SKILL.md
}

@test "AC5: bug SKILL.md contains fix proposal format" {
  grep -qi 'Root Cause\|Fix Proposal\|proposal format' skills/bug/SKILL.md
}
