#!/usr/bin/env bats
# @covers: skills/merging-and-deploying/SKILL.md templates/docs/issues/retrospective.md
# AT-349: retrospective の actionable findings を Issue 化する手順を正典化する
# Issue #349
#
# Asserts invariants (no exact-version/date/line-count pin, #289).
# 本 Issue は docs / skill-content 変更のみ。scripts/retrospective.sh 本体には触れない
# （#348 と責務分離）。AT-349-7 でその不変性を回帰確認する。
#
# lifecycle: [green]

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

setup() {
  REPO="$(repo_root)"
  SKILL="${REPO}/skills/merging-and-deploying/SKILL.md"
  TEMPLATE="${REPO}/templates/docs/issues/retrospective.md"
}

# ---------------------------------------------------------------------------
# AT-349-1: broken/anomalous metrics -> type:bug filing
# ---------------------------------------------------------------------------

@test "AT-349-1: SKILL.md Step 5 mentions type:bug filing" {
  grep -q 'type:bug' "$SKILL"
}

@test "AT-349-1: SKILL.md states broken/anomalous metric criterion (Japanese)" {
  grep -qE '壊れた|異常' "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-349-2: friction point / improvement candidate -> skill-fix filing
# ---------------------------------------------------------------------------

@test "AT-349-2: SKILL.md guides the atdd-kit:skill-fix route" {
  grep -q 'atdd-kit:skill-fix' "$SKILL"
}

@test "AT-349-2: SKILL.md mentions friction point / improvement candidate" {
  grep -qE 'friction point|improvement candidate' "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-349-3: non-actionable -> skip criteria
# ---------------------------------------------------------------------------

@test "AT-349-3: SKILL.md states non-actionable findings are skipped (Japanese)" {
  grep -qE '非アクション' "$SKILL"
  grep -qE 'スキップ' "$SKILL"
}

@test "AT-349-3: SKILL.md states threshold/error-message criteria (Japanese)" {
  grep -qE '閾値' "$SKILL"
  grep -qE 'エラーメッセージ' "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-349-4: filed Issue numbers appended to summary + all-channel sync
# ---------------------------------------------------------------------------

@test "AT-349-4: SKILL.md states filed Issue numbers are appended to the retrospective summary (Japanese)" {
  grep -qE '起票した Issue 番号.*(retrospective )?サマリ' "$SKILL"
}

@test "AT-349-4: SKILL.md states all-channel sync (terminal + Issue/PR comment) (Japanese)" {
  grep -qE '全チャネル同期' "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-349-5: no-auto-routing / human final confirmation
# ---------------------------------------------------------------------------

@test "AT-349-5: SKILL.md states no auto-routing" {
  grep -qE 'auto-routing' "$SKILL"
}

@test "AT-349-5: SKILL.md states human makes the final confirmation (Japanese)" {
  grep -qE '人間が最終確認' "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-349-6: retrospective template Improvement Candidates section updated
# ---------------------------------------------------------------------------

@test "AT-349-6: template retrospective.md lists the bug/skill-fix/skip classification" {
  grep -qE 'bug' "$TEMPLATE"
  grep -qE 'skill-fix' "$TEMPLATE"
  grep -qE 'skip' "$TEMPLATE"
}

@test "AT-349-6: template retrospective.md states filed numbers are appended to this summary (Japanese)" {
  grep -qE '本サマリに追記' "$TEMPLATE"
}

@test "AT-349-6: template retrospective.md defers detailed procedure to SKILL.md" {
  grep -qE 'SKILL\.md' "$TEMPLATE"
}

@test "AT-349-6: template retrospective.md no longer has the old No Auto-Routing passive note" {
  local count
  count=$(grep -c 'No Auto-Routing: 候補を列挙するのみ。自動起票は行わない' "$TEMPLATE" || true)
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AT-349-7: scripts/retrospective.sh has no diff (responsibility separation, regression)
# ---------------------------------------------------------------------------

@test "AT-349-7: scripts/retrospective.sh is not among this branch's changed files" {
  cd "$REPO"
  local count
  count=$(git diff --name-only origin/main...HEAD -- scripts/retrospective.sh | wc -l | tr -d ' ')
  [ "$count" -eq 0 ]
}
