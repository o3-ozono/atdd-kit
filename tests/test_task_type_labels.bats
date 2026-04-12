#!/usr/bin/env bats

# Issue #34 AC5: Task type label consolidation (investigation -> research)

@test "AC5: templates/issue/en/research.yml exists" {
  [[ -f "templates/issue/en/research.yml" ]]
}

@test "AC5: templates/issue/ja/research.yml exists" {
  [[ -f "templates/issue/ja/research.yml" ]]
}

@test "AC5: templates/issue/en/investigation.yml does not exist" {
  [[ ! -f "templates/issue/en/investigation.yml" ]]
}

@test "AC5: templates/issue/ja/investigation.yml does not exist" {
  [[ ! -f "templates/issue/ja/investigation.yml" ]]
}

@test "AC5: .github/ISSUE_TEMPLATE/research.yml exists" {
  [[ -f ".github/ISSUE_TEMPLATE/research.yml" ]]
}

@test "AC5: .github/ISSUE_TEMPLATE/research-ja.yml exists" {
  [[ -f ".github/ISSUE_TEMPLATE/research-ja.yml" ]]
}

@test "AC5: .github/ISSUE_TEMPLATE/investigation.yml does not exist" {
  [[ ! -f ".github/ISSUE_TEMPLATE/investigation.yml" ]]
}

@test "AC5: .github/ISSUE_TEMPLATE/investigation-ja.yml does not exist" {
  [[ ! -f ".github/ISSUE_TEMPLATE/investigation-ja.yml" ]]
}

@test "AC5: research template uses type:research label" {
  grep -q 'type:research' templates/issue/en/research.yml
}

@test "AC5: setup-github references type:research label" {
  grep -q 'type:research' commands/setup-github.md
}

@test "AC5: issue skill references research task type" {
  grep -q 'research' skills/issue/SKILL.md
  ! grep -q 'investigation' skills/issue/SKILL.md
}
