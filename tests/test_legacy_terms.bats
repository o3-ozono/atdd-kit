#!/usr/bin/env bats
# @covers: docs/**
# Issue #34 AC7: No legacy terms remain (excluding CHANGELOG.md)

@test "AC7: no 'type:investigation' label in any file" {
  local result
  result=$(grep -rn 'type:investigation' --include='*.md' --include='*.yml' --include='*.json' --exclude-dir='.claude' --exclude-dir='.git' . | grep -v CHANGELOG.md || true)
  [[ -z "$result" ]]
}

@test "AC7: no 'ready-to-implement' (or underscore variant) in source files" {
  # `ready-to-implement` was renamed to `ready-to-go` (#34). Only CHANGELOG.md
  # retains it as historical record; it must not appear in any other source file.
  # (The scrumban.md deprecated-label exception was dropped when the GitHub
  # Projects board tooling was removed in #238.)
  local result
  result=$(grep -rEn 'ready.to.implement' --include='*.md' --include='*.yml' --include='*.json' --exclude-dir='.claude' --exclude-dir='.git' . | grep -v CHANGELOG.md || true)
  [[ -z "$result" ]]
}

@test "AC7: no files named 'investigation' exist" {
  local result
  result=$(find . -name '*investigation*' -not -path '*/CHANGELOG.md' -not -path '*/.git/*' -not -path '*/.claude/*' 2>/dev/null || true)
  [[ -z "$result" ]]
}

@test "AC7: debugging SKILL.md has no investigation task type reference" {
  ! grep -q 'type:investigation' skills/debugging/SKILL.md
}
