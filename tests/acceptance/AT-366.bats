#!/usr/bin/env bats
# @covers: templates/docs/issues/prd.md skills/defining-requirements/SKILL.md tests/test_docs_issues_templates.bats tests/test_defining_requirements_skill.bats tests/e2e/defining-requirements.bats docs/testing-skills.md
# AT-366: defining-requirements / prd テンプレを 4 要素構造へ再編し問題定義品質規律を導入
# Issue #366
#
# AT modality: skill/doc BATS pin (#355 F4) — テンプレ再編・SKILL.md 更新は
# behavior change ではなく doc/skill content change のため。
#
# lifecycle: [green]

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

setup() {
  REPO="$(repo_root)"
  PRD_TMPL="${REPO}/templates/docs/issues/prd.md"
  SKILL_FILE="${REPO}/skills/defining-requirements/SKILL.md"
}

# ---------------------------------------------------------------------------
# AT-366-1: PRD テンプレが 4 要素構造の見出しを持つ（US-1）
# ---------------------------------------------------------------------------

@test "AT-366-1: prd.md has the 4-element headings in order" {
  local h1 h2 h3 h4
  h1=$(grep -n "^## 1\. 基礎項目" "$PRD_TMPL" | head -1 | cut -d: -f1)
  h2=$(grep -n "^## 2\. 問題定義と背景" "$PRD_TMPL" | head -1 | cut -d: -f1)
  h3=$(grep -n "^## 3\. ゴールと成功指標" "$PRD_TMPL" | head -1 | cut -d: -f1)
  h4=$(grep -n "^## 4\. 機能要件" "$PRD_TMPL" | head -1 | cut -d: -f1)
  [ -n "$h1" ]
  [ -n "$h2" ]
  [ -n "$h3" ]
  [ -n "$h4" ]
  [ "$h1" -lt "$h2" ]
  [ "$h2" -lt "$h3" ]
  [ "$h3" -lt "$h4" ]
}

@test "AT-366-1: prd.md does not retain the old 6-section headings as standalone headings" {
  ! grep -qE "^## Problem$" "$PRD_TMPL"
  ! grep -qE "^## Why now$" "$PRD_TMPL"
  ! grep -qE "^## Outcome$" "$PRD_TMPL"
  ! grep -qE "^## What$" "$PRD_TMPL"
  ! grep -qE "^## Non-Goals$" "$PRD_TMPL"
}

@test "AT-366-1: prd.md retains the Open Questions heading" {
  grep -qE "^## Open Questions" "$PRD_TMPL"
}

# ---------------------------------------------------------------------------
# AT-366-2: 問題定義節が事実欄と課題欄を分離している（US-1）
# ---------------------------------------------------------------------------

@test "AT-366-2: problem section separates a Facts label and an Issue label" {
  grep -qE "事実" "$PRD_TMPL"
  grep -qE "課題" "$PRD_TMPL"
}

@test "AT-366-2: problem section carries guidance to keep facts and issues separate" {
  grep -qiE "事実.*課題.*分離|分けて書く" "$PRD_TMPL"
}

# ---------------------------------------------------------------------------
# AT-366-3: 品質規律 4 原則がテンプレ内に明示されている（US-1）
# ---------------------------------------------------------------------------

@test "AT-366-3: the 4 quality-discipline principles all appear" {
  grep -qE "事実と課題の分離" "$PRD_TMPL"
  grep -qE "1 *PRD *= *1.*課題" "$PRD_TMPL"
  grep -qE "観察可能なゴール" "$PRD_TMPL"
  grep -qE "下流からの還流" "$PRD_TMPL"
}

@test "AT-366-3: the originality marker is attached to the two atdd-kit-original principles" {
  grep -qE "1.*PRD.*=.*1.*課題.*\[独自\]|\[独自\].*1.*PRD.*=.*1.*課題" "$PRD_TMPL"
  grep -qE "下流からの還流.*\[独自\]|\[独自\].*下流からの還流" "$PRD_TMPL"
}

# ---------------------------------------------------------------------------
# AT-366-4: anti-pattern 集がテンプレ内に存在する（US-1）
# ---------------------------------------------------------------------------

@test "AT-366-4: the 4 anti-patterns are documented" {
  grep -qE "事実.*課題.*混在|課題.*事実.*混在" "$PRD_TMPL"
  grep -qE "複数課題の同居|複数の(本質)?課題.*同居" "$PRD_TMPL"
  grep -qE "内部完了条件のゴール|内部完了条件" "$PRD_TMPL"
  grep -qE "観察不可能な成功指標|観察不可能" "$PRD_TMPL"
}

# ---------------------------------------------------------------------------
# AT-366-5: ゴール節が観察可能性の規律を持つ（US-1）
# ---------------------------------------------------------------------------

@test "AT-366-5: goal section forbids internal completion-condition wording" {
  grep -qE "内部完了条件" "$PRD_TMPL"
  grep -qiE "観察可能" "$PRD_TMPL"
}

# ---------------------------------------------------------------------------
# AT-366-6: 機能要件節がスコープ外欄と優先度プレースホルダーを持つ（US-1）
# ---------------------------------------------------------------------------

@test "AT-366-6: functional requirements section has a scope-out field and a priority placeholder" {
  grep -qE "スコープ外" "$PRD_TMPL"
  grep -qE "優先度" "$PRD_TMPL"
}

# ---------------------------------------------------------------------------
# AT-366-7: 旧 6 節 ↔ 新 4 要素の対応表が存在する（US-3）
# ---------------------------------------------------------------------------

@test "AT-366-7: old-6-section-to-new-4-element mapping table exists in the template" {
  grep -qE "^## 1\. 基礎項目" "$PRD_TMPL"
  grep -qE "Problem" "$PRD_TMPL"
  grep -qE "Why now" "$PRD_TMPL"
  grep -qE "Outcome" "$PRD_TMPL"
  grep -qE "Non-Goals" "$PRD_TMPL"
}

# ---------------------------------------------------------------------------
# AT-366-8: Open Questions 節が Resolved/Unresolved 管理ガイダンスを持つ（US-1）
# ---------------------------------------------------------------------------

@test "AT-366-8: Open Questions section has Resolved/Unresolved guidance" {
  grep -qE "Resolved" "$PRD_TMPL"
  grep -qE "Unresolved" "$PRD_TMPL"
  grep -qE "\[独自\]" "$PRD_TMPL"
}

# ---------------------------------------------------------------------------
# AT-366-9: defining-requirements スキルが 4 要素構造の対話規律を持つ（US-2）
# ---------------------------------------------------------------------------

@test "AT-366-9: SKILL.md Flow addresses the 4-element structure" {
  grep -qE "基礎項目" "$SKILL_FILE"
  grep -qE "問題定義" "$SKILL_FILE"
  grep -qiE "ゴール|goal" "$SKILL_FILE"
  grep -qE "機能要件" "$SKILL_FILE"
}

@test "AT-366-9: SKILL.md Flow keeps the one-question-at-a-time / AskUserQuestion discipline" {
  grep -qiE "one question at a time|一問一答|1 質問ずつ" "$SKILL_FILE"
}

@test "AT-366-9: SKILL.md no longer assumes the old '6 sections' framing" {
  ! grep -qiE "6 PRD sections|6 sections" "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AT-366-10: 既存 PRD 資産が旧 6 節形式のまま温存される（CS-2）
# ---------------------------------------------------------------------------

@test "AT-366-10: pre-existing docs/issues/*/prd.md files are untouched (backward compat)" {
  # This Issue's own PRD is expected to change (it documents this very Issue);
  # every other Issue's prd.md must have zero diff against the merge base.
  local base
  base="$(git -C "$REPO" merge-base HEAD origin/main 2>/dev/null || git -C "$REPO" merge-base HEAD main 2>/dev/null || echo "")"
  if [ -z "$base" ]; then
    skip "no merge base against main found — cannot assert zero-diff invariant"
  fi
  local changed
  changed=$(git -C "$REPO" diff --name-only "$base" -- 'docs/issues/*/prd.md' \
    | grep -v '^docs/issues/366-prd-problem-definition/prd\.md$' || true)
  [ -z "$changed" ]
}

# ---------------------------------------------------------------------------
# AT-366-11: version と CHANGELOG が整合する（Finishing / 不変条件）
# ---------------------------------------------------------------------------

@test "AT-366-11: plugin.json version matches the topmost CHANGELOG release heading" {
  local plugin_version changelog_version
  plugin_version=$(grep -m1 '"version"' "${REPO}/.claude-plugin/plugin.json" | sed -E 's/.*"version": *"([^"]+)".*/\1/')
  changelog_version=$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "${REPO}/CHANGELOG.md" | sed -E 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/')
  [ -n "$plugin_version" ]
  [ -n "$changelog_version" ]
  [ "$plugin_version" = "$changelog_version" ]
}
