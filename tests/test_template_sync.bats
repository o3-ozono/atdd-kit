#!/usr/bin/env bats
# @covers: .claude-plugin/**
# Verify templates/issue/ and templates/pr/ stay in sync with .github/ copies.
# Prevents silent divergence between source templates and deployed copies.

@test "en issue templates match .github/ISSUE_TEMPLATE copies" {
  for src in templates/issue/en/*.yml; do
    base=$(basename "$src")
    target=".github/ISSUE_TEMPLATE/${base}"
    [ -f "$target" ] || { echo "missing: $target"; return 1; }
    diff "$src" "$target" || { echo "diverged: $src vs $target"; return 1; }
  done
}

@test "ja issue templates match .github/ISSUE_TEMPLATE copies" {
  for src in templates/issue/ja/*.yml; do
    base=$(basename "$src" .yml)
    target=".github/ISSUE_TEMPLATE/${base}-ja.yml"
    [ -f "$target" ] || { echo "missing: $target"; return 1; }
    diff "$src" "$target" || { echo "diverged: $src vs $target"; return 1; }
  done
}

@test "PR template matches .github/pull_request_template.md copy" {
  [ -f "templates/pr/en/pull_request_template.md" ] || { echo "missing source"; return 1; }
  [ -f ".github/pull_request_template.md" ] || { echo "missing target"; return 1; }
  diff "templates/pr/en/pull_request_template.md" ".github/pull_request_template.md" \
    || { echo "diverged: templates/pr/en/ vs .github/"; return 1; }
}
