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

# AC3: plan.md — task行 + verify:行 交互配置

@test "AC3: plan.md exists" {
  [ -f "templates/docs/issues/plan.md" ]
}

@test "AC3: plan.md has task checkbox line" {
  grep -q "^\- \[ \]" templates/docs/issues/plan.md
}

@test "AC3: plan.md has verify: line" {
  grep -q "verify:" templates/docs/issues/plan.md
}

# AC4: acceptance-tests.md — 4 状態マーカー（planned/draft/green/regression）

@test "AC4: acceptance-tests.md exists" {
  [ -f "templates/docs/issues/acceptance-tests.md" ]
}

@test "AC4: acceptance-tests.md has [planned] marker" {
  grep -q "\[planned\]" templates/docs/issues/acceptance-tests.md
}

@test "AC4: acceptance-tests.md has [draft] marker" {
  grep -q "\[draft\]" templates/docs/issues/acceptance-tests.md
}

@test "AC4: acceptance-tests.md has [green] marker" {
  grep -q "\[green\]" templates/docs/issues/acceptance-tests.md
}

@test "AC4: acceptance-tests.md has [regression] marker" {
  grep -q "\[regression\]" templates/docs/issues/acceptance-tests.md
}
