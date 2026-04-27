#!/usr/bin/env bats
# @covers: docs/**
# Issue #34 AC7: No legacy terms remain (excluding CHANGELOG.md)

@test "AC7: no 'type:investigation' label in any file" {
  local result
  result=$(grep -rn 'type:investigation' --include='*.md' --include='*.yml' --include='*.json' --exclude-dir='.claude' --exclude-dir='.git' . | grep -v CHANGELOG.md || true)
  [[ -z "$result" ]]
}

@test "AC7: no 'ready-to-implement' (or underscore variant) in source files" {
  # docs/methodology/scrumban.md is the canonical place that documents
  # `ready-to-implement` as a deprecated label (per Issue #166 Plan Round 1).
  # Keep scrumban.md as the only allowed mention so Phase D (#170) can
  # consume the full label correspondence table.
  local result
  result=$(grep -rEn 'ready.to.implement' --include='*.md' --include='*.yml' --include='*.json' --exclude-dir='.claude' --exclude-dir='.git' . | grep -v CHANGELOG.md | grep -v 'docs/methodology/scrumban.md' || true)
  [[ -z "$result" ]]
}

@test "AC7: no files named 'investigation' exist" {
  local result
  result=$(find . -name '*investigation*' -not -path '*/CHANGELOG.md' -not -path '*/.git/*' -not -path '*/.claude/*' 2>/dev/null || true)
  [[ -z "$result" ]]
}

@test "AC7: discover SKILL.md uses research instead of investigation for task type" {
  ! grep -q 'type:investigation' skills/discover/SKILL.md
}

@test "AC7: debugging SKILL.md has no investigation task type reference" {
  ! grep -q 'type:investigation' skills/debugging/SKILL.md
}
