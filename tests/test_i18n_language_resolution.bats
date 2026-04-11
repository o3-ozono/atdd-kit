#!/usr/bin/env bats

# Language resolution logic was removed.
# These tests verify the removal is complete.

@test "docs/language-resolution.md does not exist" {
  [[ ! -f "docs/language-resolution.md" ]]
}

@test "docs/i18n-strategy.md does not exist" {
  [[ ! -f "docs/i18n-strategy.md" ]]
}

@test "rules/atdd-kit.md does not reference language resolution" {
  ! grep -qi 'language-resolution\|language.*resolut' rules/atdd-kit.md
}

@test "rules/atdd-kit.md does not reference i18n" {
  ! grep -qi 'i18n' rules/atdd-kit.md
}

@test "rules/atdd-kit.md stays within 40-line budget" {
  local lines
  lines=$(wc -l < rules/atdd-kit.md)
  [[ "$lines" -le 40 ]]
}
