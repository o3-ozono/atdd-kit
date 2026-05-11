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

# AC2: user-stories.md — Connextra 形式 + Pichler 制約 Story

@test "AC2: user-stories.md exists" {
  [ -f "templates/docs/issues/user-stories.md" ]
}

@test "AC2: user-stories.md has Connextra 'As a' pattern" {
  grep -q "As a" templates/docs/issues/user-stories.md
}

@test "AC2: user-stories.md has Connextra 'I want to' pattern" {
  grep -q "I want to" templates/docs/issues/user-stories.md
}

@test "AC2: user-stories.md has Connextra 'so that' pattern" {
  grep -q "so that" templates/docs/issues/user-stories.md
}

@test "AC2: user-stories.md has Pichler constraint story keyword" {
  grep -qiE "constraint|NFR|In order to|non-functional" templates/docs/issues/user-stories.md
}
