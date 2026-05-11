#!/usr/bin/env bats
# @covers: templates/docs/issues/**

# AC1: prd.md — 6 見出し + <!-- コメント

@test "AC1: prd.md exists" {
  [ -f "templates/docs/issues/prd.md" ]
}

@test "AC1: prd.md has ## Problem heading" {
  grep -q "^## Problem" templates/docs/issues/prd.md
}

@test "AC1: prd.md has ## Why now heading" {
  grep -q "^## Why now" templates/docs/issues/prd.md
}

@test "AC1: prd.md has ## Outcome heading" {
  grep -q "^## Outcome" templates/docs/issues/prd.md
}

@test "AC1: prd.md has ## What heading" {
  grep -q "^## What" templates/docs/issues/prd.md
}

@test "AC1: prd.md has ## Non-Goals heading" {
  grep -q "^## Non-Goals" templates/docs/issues/prd.md
}

@test "AC1: prd.md has ## Open Questions heading" {
  grep -q "^## Open Questions" templates/docs/issues/prd.md
}

@test "AC1: prd.md has at least one HTML guide comment" {
  grep -q "<!--" templates/docs/issues/prd.md
}
