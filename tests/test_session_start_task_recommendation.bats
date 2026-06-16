#!/usr/bin/env bats
# @covers: skills/session-start/SKILL.md
# Issue #187: fix: session-start の推奨タスクが in-progress Issue を除外しない

SKILL_EN="skills/session-start/SKILL.md"
ROUTE_ELIGIBILITY="docs/methodology/route-eligibility.md"

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
  # 信号文字列は route-eligibility.md が単一ソース（#304 FS-1）
  grep -qiE 'docs|README|typo|gitignore|version.bump' "$ROUTE_ELIGIBILITY"
}

@test "#302-AC2: Step 3 has autopilot signals" {
  # 信号文字列は route-eligibility.md が単一ソース（#304 FS-1）
  # 英語シグナル（new feature / behavior change）と日本語シグナルの両方を含む完全セットを確認する（#304 finding #2）
  grep -qiE 'new feature|behavior|CI|hooks|depend|security|新機能|挙動変更|依存|セキュリティ' "$ROUTE_ELIGIBILITY"
}

@test "#302-AC2: Step 3 specifies hybrid determination (label + keyword + LLM)" {
  # ハイブリッド判定の 3 要素は route-eligibility.md に集約（#304 FS-1）
  grep -qi 'label' "$ROUTE_ELIGIBILITY"
  grep -qiE 'keyword|キーワード' "$ROUTE_ELIGIBILITY"
  grep -qi 'LLM' "$ROUTE_ELIGIBILITY"
}

@test "#302-AC3: Step 3 documents fallback to autopilot when ambiguous" {
  # 曖昧時フォールバックは route-eligibility.md が単一ソース（#304 FS-1）
  grep -qiE 'doubt|ambiguous|unclear|曖昧|不明' "$ROUTE_ELIGIBILITY"
}

@test "#302-AC4: Step 3 states recommendation only -- no auto-routing" {
  # 推奨のみ不変条件は route-eligibility.md が単一ソース（#304 FS-1）
  grep -qiE '推奨のみ|recommendation only|auto.route.*not|not.*auto.route|自動.*しない|しない.*自動' "$ROUTE_ELIGIBILITY"
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

# --- #316: Draft PR layer-1 pins ---

@test "#316-AC1: SKILL.md limits CONFLICTING rebase to ready (non-Draft) @me PRs" {
  # The rebase recommendation must mention ready/non-Draft and @me conditions
  local step2
  step2=$(sed -n '/Step 2/,/Step 3/p' "$SKILL_EN")
  echo "$step2" | grep -qiE 'ready.*non.draft|non.draft.*ready'
  echo "$step2" | grep -q '@me'
}

@test "#316-AC2: SKILL.md states Draft PRs must not have write-back proposed" {
  local step2
  step2=$(sed -n '/Step 2/,/Step 3/p' "$SKILL_EN")
  echo "$step2" | grep -qiE 'draft.*not|not.*draft|draft.*never'
  echo "$step2" | grep -qiE 'git checkout|git rebase|git push'
}

@test "#316-AC3: SKILL.md shows Draft PR as read-only in Previous Work example" {
  grep -qiE 'read-only|read only' "$SKILL_EN"
}

@test "#316-AC4: SKILL.md includes read-only working-on-branch marker text" {
  grep -q '別セッション作業中' "$SKILL_EN"
}

@test "#316-regression: existing #187 in-progress exclusion pin is intact" {
  local section
  section=$(sed -n '/Task Recommendation Rules/,/^## /p' "$SKILL_EN")
  echo "$section" | grep -q 'in-progress'
  echo "$section" | grep -qi 'exclu'
}

@test "#316-regression: existing #302 4-column Recommended Tasks header is intact" {
  grep -qE '\|\s*Priority\s*\|\s*Issue\s*\|\s*Reason\s*\|\s*推奨経路\s*\|' "$SKILL_EN"
}
