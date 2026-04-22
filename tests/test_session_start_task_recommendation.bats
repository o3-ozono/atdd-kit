#!/usr/bin/env bats
# @covers: skills/session-start/SKILL.md
# Issue #187: fix: session-start の推奨タスクが in-progress Issue を除外しない

SKILL_EN="skills/session-start/SKILL.md"

# --- AC1: in-progress Issue の除外 ---

@test "#187-AC1: SKILL.md excludes in-progress Issues in Step 1" {
  local section
  section=$(sed -n '/Task Recommendation Rules/,/^## /p' "$SKILL_EN")
  echo "$section" | grep -q 'in-progress'
  echo "$section" | grep -qi 'exclu'
}

# --- AC2: 除外リスト構築手順の明示化 ---

@test "#187-AC2: SKILL.md has Step 1 (exclusion list)" {
  local section
  section=$(sed -n '/Task Recommendation Rules/,/^## /p' "$SKILL_EN")
  echo "$section" | grep -qi 'Step 1'
  echo "$section" | grep -qi 'exclusion\|exclude'
}

@test "#187-AC2: SKILL.md has Step 2 (filter and rank)" {
  local section
  section=$(sed -n '/Task Recommendation Rules/,/^## /p' "$SKILL_EN")
  echo "$section" | grep -qi 'Step 2'
  echo "$section" | grep -qi 'filter\|rank'
}

@test "#187-AC2: SKILL.md Step 1 lists in-progress as exclusion condition" {
  local section
  section=$(sed -n '/Step 1/,/Step 2/p' "$SKILL_EN")
  echo "$section" | grep -q 'in-progress'
}

@test "#187-AC2: SKILL.md Step 1 lists open PR as exclusion condition" {
  local section
  section=$(sed -n '/Step 1/,/Step 2/p' "$SKILL_EN")
  echo "$section" | grep -qi 'open PR\|open.*pull request\|open PRs'
}

# --- AC3: SKILL.ja.md no longer exists (English-only) ---

@test "#187-AC3: SKILL.ja.md does not exist" {
  [[ ! -f "skills/session-start/SKILL.ja.md" ]]
}

# --- Regression: 既存ルールの維持 ---

@test "#187-regression: SKILL.md Step 2 preserves priority label ranking" {
  local section
  section=$(sed -n '/Task Recommendation Rules/,/^## /p' "$SKILL_EN")
  echo "$section" | grep -q 'p1.*p2.*p3'
}

@test "#187-regression: SKILL.md Step 2 preserves type priority" {
  local section
  section=$(sed -n '/Task Recommendation Rules/,/^## /p' "$SKILL_EN")
  echo "$section" | grep -qi 'bug.*feature\|bug.*refactor'
}
