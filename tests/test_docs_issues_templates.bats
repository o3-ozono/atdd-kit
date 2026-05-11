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

# AC5: design-doc.md — 7 見出し（Ubl 2020 形式）

@test "AC5: design-doc.md exists" {
  [ -f "templates/docs/issues/design-doc.md" ]
}

@test "AC5: design-doc.md has ## Context heading" {
  grep -q "^## Context" templates/docs/issues/design-doc.md
}

@test "AC5: design-doc.md has ## Goals heading" {
  grep -q "^## Goals" templates/docs/issues/design-doc.md
}

@test "AC5: design-doc.md has ## Non-Goals heading" {
  grep -q "^## Non-Goals" templates/docs/issues/design-doc.md
}

@test "AC5: design-doc.md has ## Proposal heading" {
  grep -q "^## Proposal" templates/docs/issues/design-doc.md
}

@test "AC5: design-doc.md has ## Alternatives Considered heading" {
  grep -q "^## Alternatives Considered" templates/docs/issues/design-doc.md
}

@test "AC5: design-doc.md has ## Trade-offs heading" {
  grep -q "^## Trade-offs" templates/docs/issues/design-doc.md
}

@test "AC5: design-doc.md has ## Risks heading" {
  grep -q "^## Risks" templates/docs/issues/design-doc.md
}

# AC6: README.md — 5 テンプレート名・cp 例・docs/issues/NNN/・design-doc 任意性注記

@test "AC6: templates/docs/issues/README.md exists" {
  [ -f "templates/docs/issues/README.md" ]
}

@test "AC6: README.md lists prd.md" {
  grep -q "prd.md" templates/docs/issues/README.md
}

@test "AC6: README.md lists user-stories.md" {
  grep -q "user-stories.md" templates/docs/issues/README.md
}

@test "AC6: README.md lists plan.md" {
  grep -q "plan.md" templates/docs/issues/README.md
}

@test "AC6: README.md lists acceptance-tests.md" {
  grep -q "acceptance-tests.md" templates/docs/issues/README.md
}

@test "AC6: README.md lists design-doc.md" {
  grep -q "design-doc.md" templates/docs/issues/README.md
}

@test "AC6: README.md has cp command example" {
  grep -q "^cp " templates/docs/issues/README.md
}

@test "AC6: README.md mentions docs/issues/NNN/" {
  grep -q "docs/issues/NNN/" templates/docs/issues/README.md
}

@test "AC6: README.md notes design-doc is optional" {
  grep -qiE "optional|任意" templates/docs/issues/README.md
}
