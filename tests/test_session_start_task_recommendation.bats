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

@test "#187-regression: SKILL.md Step 2 preserves type priority" {
  local section
  section=$(sed -n '/Task Recommendation Rules/,/^## /p' "$SKILL_EN")
  echo "$section" | grep -qi 'bug.*feature\|bug.*refactor'
}

# --- #302: Route recommendation (Step 3) ---

@test "#302-AC1: Recommended Tasks template has 4-column header with route column" {
  grep -qE '\|\s*Priority\s*\|\s*Issue\s*\|\s*Reason\s*\|\s*推奨経路\s*\|' "$SKILL_EN"
}

@test "#302-AC2: Task Recommendation Rules has Step 3" {
  local section
  section=$(sed -n '/Task Recommendation Rules/,/^## /p' "$SKILL_EN")
  echo "$section" | grep -qi 'Step 3'
}

@test "#302-AC2: Step 3 has express-eligible signals" {
  local section
  section=$(sed -n '/Step 3/,/^## \|^###/p' "$SKILL_EN")
  echo "$section" | grep -qiE 'docs|README|typo|gitignore|version.bump'
}

@test "#302-AC2: Step 3 has autopilot signals" {
  local section
  section=$(sed -n '/Step 3/,/^## \|^###/p' "$SKILL_EN")
  echo "$section" | grep -qiE 'CI|hooks|depend|security|new feature|behavior|新機能|挙動変更|依存|セキュリティ'
}

@test "#302-AC2: Step 3 specifies hybrid determination (label + keyword + LLM)" {
  local section
  section=$(sed -n '/Step 3/,/^## \|^###/p' "$SKILL_EN")
  echo "$section" | grep -qi 'label'
  echo "$section" | grep -qiE 'keyword|キーワード'
  echo "$section" | grep -qi 'LLM'
}

@test "#302-AC3: Step 3 documents fallback to autopilot when ambiguous" {
  local section
  section=$(sed -n '/Step 3/,/^## \|^###/p' "$SKILL_EN")
  echo "$section" | grep -qiE 'doubt|ambiguous|unclear|曖昧|不明'
}

@test "#302-AC4: Step 3 states recommendation only -- no auto-routing" {
  local section
  section=$(sed -n '/Step 3/,/^## \|^###/p' "$SKILL_EN")
  echo "$section" | grep -qiE '推奨のみ|recommendation only|auto.route.*not|not.*auto.route|自動.*しない|しない.*自動'
}

# --- #302-AC5: express の既存トリガ温存（リグレッション） ---

SKILL_EXPRESS="skills/express/SKILL.md"

@test "#302-AC5: express SKILL.md still has APPROVAL-GATE" {
  grep -q 'APPROVAL-GATE' "$SKILL_EXPRESS"
}

@test "#302-AC5: express SKILL.md still has scope-overflow guard" {
  grep -qiE 'scope.overflow|scope overflow' "$SKILL_EXPRESS"
}

@test "#302-AC5: express SKILL.md still has OK/NG criteria" {
  grep -qiE '\*\*OK|OK.*applies|\*\*NG|NG.*does not apply|OK 基準|NG 基準' "$SKILL_EXPRESS"
}
