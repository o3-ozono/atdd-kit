#!/usr/bin/env bats

# Issue #34 AC7: No legacy terms remain (excluding CHANGELOG.md and docs/decisions/)

@test "AC7: no 'type:investigation' label in any file" {
  local result
  result=$(grep -rn 'type:investigation' --include='*.md' --include='*.yml' --include='*.json' . | grep -v CHANGELOG.md | grep -v 'docs/decisions/' || true)
  [[ -z "$result" ]]
}

@test "AC7: no 'ready-to-implement' in source files" {
  local result
  result=$(grep -rn 'ready-to-implement' --include='*.md' --include='*.yml' --include='*.json' . | grep -v CHANGELOG.md | grep -v 'docs/decisions/' || true)
  [[ -z "$result" ]]
}

@test "AC7: no files named 'investigation' exist" {
  local result
  result=$(find . -name '*investigation*' -not -path '*/CHANGELOG.md' -not -path '*/docs/decisions/*' -not -path '*/.git/*' 2>/dev/null || true)
  [[ -z "$result" ]]
}

@test "AC7: discover SKILL.md uses research instead of investigation for task type" {
  ! grep -q 'type:investigation' skills/discover/SKILL.md
}

@test "AC7: debugging SKILL.md has no investigation task type reference" {
  ! grep -q 'type:investigation' skills/debugging/SKILL.md
}
