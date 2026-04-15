#!/usr/bin/env bats
# Test: PR #142 Agent Teams doc sync verification (#146)

# CC1: README command table updated
@test "CC1: README.md does not contain auto-implement command" {
  ! grep -q '/atdd-kit:auto-implement' README.md
}

@test "CC1: README.md does not contain auto-review command" {
  ! grep -q '/atdd-kit:auto-review' README.md
}

@test "CC1: README.ja.md does not contain auto-implement command" {
  ! grep -q '/atdd-kit:auto-implement' README.ja.md
}

@test "CC1: README.ja.md does not contain auto-review command" {
  ! grep -q '/atdd-kit:auto-review' README.ja.md
}

# CC2: README ATDD workflow Mermaid diagram
@test "CC2: README.md contains ATDD workflow mermaid block" {
  grep -q 'flowchart LR' README.md
}

@test "CC2: README.ja.md contains ATDD workflow mermaid block" {
  grep -q 'flowchart LR' README.ja.md
}

# CC3: README Agent Teams Mermaid diagram
@test "CC3: README.md contains Agent Teams mermaid block with PO" {
  grep -q 'PO' README.md
}

@test "CC3: README.md contains Agent Teams flowchart TD" {
  grep -q 'flowchart TD' README.md
}

@test "CC3: README.ja.md contains Agent Teams flowchart TD" {
  grep -q 'flowchart TD' README.ja.md
}

# CC4: DEVELOPMENT.md old references removed
@test "CC4: DEVELOPMENT.md does not reference auto-implement" {
  ! grep -q 'auto-implement' DEVELOPMENT.md
}

@test "CC4: DEVELOPMENT.md does not reference auto-review" {
  ! grep -q 'auto-review' DEVELOPMENT.md
}

@test "CC4: DEVELOPMENT.ja.md does not reference auto-implement" {
  ! grep -q 'auto-implement' DEVELOPMENT.ja.md
}

@test "CC4: DEVELOPMENT.ja.md does not reference auto-review" {
  ! grep -q 'auto-review' DEVELOPMENT.ja.md
}

# CC5: docs/ Loaded by metadata updated
@test "CC5: error-handling.md Loaded by references autopilot (Dev)" {
  grep -q 'autopilot (Dev)' docs/guides/error-handling.md
}

@test "CC5: review-guide.md Loaded by references autopilot (QA)" {
  grep -q 'autopilot (QA)' docs/guides/review-guide.md
}

@test "CC5: autonomy-levels.md Loaded by references autopilot (QA)" {
  grep -q 'autopilot (QA)' docs/workflow/autonomy-levels.md
}

@test "CC5: workflow-detail.md Loaded by references autopilot" {
  grep -q 'Loaded by.*autopilot' docs/workflow/workflow-detail.md
}

@test "CC5: docs/*.ja.md files no longer exist (English-only)" {
  local result
  result=$(find docs/ -maxdepth 1 -name '*.ja.md' 2>/dev/null || true)
  [ -z "$result" ]
}

# CC6: docs/ body text updated
@test "CC6: workflow-detail.md does not reference auto-review" {
  ! grep -q 'auto-review' docs/workflow/workflow-detail.md
}

@test "CC6: doc-sync-checklist.md references QA (autopilot)" {
  grep -q 'QA (autopilot)' docs/guides/doc-sync-checklist.md
}

# CC7: SKILL.ja.md no longer exists
@test "CC7: skills/ship/SKILL.ja.md no longer exists" {
  [[ ! -f skills/ship/SKILL.ja.md ]]
}

# CC9: global grep — no auto-implement/auto-review outside CHANGELOG, tests, settings.local.json
@test "CC9: no auto-implement outside CHANGELOG, tests, settings.local.json, .tmp" {
  result=$(grep -rn 'auto-implement' . \
    --include="*.md" --include="*.yml" --include="*.yaml" --include="*.sh" \
    | grep -v 'CHANGELOG.md' \
    | grep -v 'tests/' \
    | grep -v '\.tmp/' \
    | grep -v '\.git/' \
    | grep -v 'settings.local.json' \
    || true)
  [ -z "$result" ]
}

@test "CC9: no auto-review outside CHANGELOG, tests, settings.local.json, skills/ship, .tmp" {
  result=$(grep -rn 'auto-review' . \
    --include="*.md" --include="*.yml" --include="*.yaml" --include="*.sh" \
    | grep -v 'CHANGELOG.md' \
    | grep -v 'tests/' \
    | grep -v 'skills/ship/' \
    | grep -v '\.tmp/' \
    | grep -v '\.git/' \
    | grep -v 'settings.local.json' \
    || true)
  [ -z "$result" ]
}
