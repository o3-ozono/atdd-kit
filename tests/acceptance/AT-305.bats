#!/usr/bin/env bats
# @covers: skills/defining-requirements/SKILL.md skills/autopilot/SKILL.md skills/merging-and-deploying/SKILL.md docs/methodology/autopilot-design-gate.md docs/guides/skill-authoring-guide.md
# Issue #305 — User gate を選択肢提示（ワンタップ承認）にする
# Story-scoped Acceptance Test (AT-001..AT-006). The deliverables are skill / doc
# edits, so these assert the structural conditions each AC requires.
#
# Anchor (AL-2): docs/issues/305-user-gate-selection/acceptance-tests.md
# 不変条件をアサートする（version・日付・行数を exact-pin しない, #289）。

DEF="skills/defining-requirements/SKILL.md"
AUTO="skills/autopilot/SKILL.md"
MERGE="skills/merging-and-deploying/SKILL.md"
# 設計承認ゲートの詳細は loader stub 分割で切り出される（finding #1）。記述は doc 側 or SKILL 本体のいずれか。
DGATE="docs/methodology/autopilot-design-gate.md"
GUIDE="docs/guides/skill-authoring-guide.md"

# 設計承認ゲート記述の所在を解決する: 切り出し doc があればそれ、無ければ autopilot 本体。
design_gate_file() {
  if [ -f "$DGATE" ]; then echo "$DGATE"; else echo "$AUTO"; fi
}

# ============================================================================
# AT-001: ワンタップ承認（Story 1）
#   各 User gate が AskUserQuestion 形式で、第一選択肢が (Recommended) 付き承認。
# ============================================================================

@test "AT-001: requirements-approval gate uses AskUserQuestion with Recommended approval first" {
  grep -q 'AskUserQuestion' "$DEF"
  # 第一選択肢が (Recommended) 付きの承認 (ok)
  grep -qiE '\(Recommended\).*承認.*\(?ok\)?' "$DEF"
}

@test "AT-001: design-approval gate uses AskUserQuestion with Recommended approval first" {
  local f; f="$(design_gate_file)"
  grep -q 'AskUserQuestion' "$f"
  grep -qiE '\(Recommended\).*承認.*\(?ok\)?' "$f"
}

@test "AT-001: merge gate uses AskUserQuestion with Recommended merge option first" {
  grep -q 'AskUserQuestion' "$MERGE"
  grep -qiE '\(Recommended\).*マージ' "$MERGE"
}

@test "AT-001 (finding #3, AL-1 traceability): autopilot Gate ① delegates to defining-requirements; no separate requirements gate" {
  # 要件承認ゲートは defining-requirements のみが提示。autopilot Gate ① は委譲する旨の注記。
  grep -qiE 'Gate ①.*(defining-requirements|委譲)|defining-requirements.*(委譲|delegat)' "$AUTO"
}

# ============================================================================
# AT-002: 文脈に応じた差し戻し選択肢（Story 2）
# ============================================================================

@test "AT-002: requirements-approval gate offers Problem/Outcome/scope revise options" {
  grep -qiE 'Problem' "$DEF"
  grep -qiE 'Outcome' "$DEF"
  grep -qiE 'スコープ' "$DEF"
}

@test "AT-002: design-approval gate offers US/Plan/AT revise options" {
  local f; f="$(design_gate_file)"
  grep -qiE 'User Stories.*修正|User Stories を修正' "$f"
  grep -qiE 'Plan.*修正|Plan を修正' "$f"
  grep -qiE 'Acceptance Tests.*修正|Acceptance Tests を修正' "$f"
}

@test "AT-002: merge gate offers hold option" {
  grep -qiE '保留' "$MERGE"
}

# ============================================================================
# AT-003: 自由記述の常設（Story 3）
#   harness 自動付与の Other を手動列挙しない／自由記述経路維持。
# ============================================================================

@test "AT-003: each gate documents Other is harness-auto and free-text route is preserved" {
  local f; f="$(design_gate_file)"
  # Other が harness 自動付与であり手動追加しない旨
  grep -qiE 'Other.*(自動|auto|手動列挙しない|手動.*追加しない)' "$DEF"
  grep -qiE 'Other.*(自動|auto|手動列挙しない|手動.*追加しない)' "$f"
  grep -qiE 'Other.*(自動|auto|手動列挙しない|手動.*追加しない)' "$MERGE"
}

# ============================================================================
# AT-004: 承認/差し戻しロジックへの忠実なマッピング（Story 4）
#   非 ok = 全体差し戻し＋セクション単位 finding 化、部分承認は承認ではない（意味論不変）。
# ============================================================================

@test "AT-004: design-gate description keeps whole-set rejection + section-wise finding + partial-approval semantics" {
  local f; f="$(design_gate_file)"
  grep -qiE '全体.*差し戻|whole.*reject|deliverable set' "$f"
  grep -qiE 'セクション単位|1 セクション.*finding|section.*finding' "$f"
  grep -qiE '部分承認.*承認ではない|部分承認は承認ではない' "$f"
}

# ============================================================================
# AT-005: 非対応チャネルへのフォールバック（Story 5）
#   各ゲートに Recommended: ... — reply 'ok' 行とフォールバック文言。
# ============================================================================

@test "AT-005: requirements-approval gate has 'recommended.*ok' fallback line" {
  grep -qiE "recommended.*ok" "$DEF"
}

@test "AT-005: design-approval gate has 'recommended.*ok' fallback line" {
  local f; f="$(design_gate_file)"
  grep -qiE "recommended.*ok" "$f"
}

@test "AT-005: merge gate has 'recommended.*ok' fallback line" {
  grep -qiE "recommended.*ok" "$MERGE"
}

# ============================================================================
# AT-006: ゲート数の不変性（AL-1）（Story 6）
#   finding #4: per-skill grep ではなく実際にカウントする機構。
#   autopilot の `## User gates` 節内の番号付き項目を数えて == 3。
# ============================================================================

@test "AT-006: autopilot User gates section still has exactly three numbered gates (AL-1, count mechanism)" {
  local gates
  gates=$(sed -n '/^## User gates/,/^## Dialog economy/p' "$AUTO" | grep -cE '^[0-9]+\. ')
  [ "$gates" -eq 3 ]
}

@test "AT-006: merging-and-deploying adds no new in-skill Flow approval gate (replacement only)" {
  # Flow 節のステップ数が増えていない（既存 5 ステップ: precondition/merge/deploy/regression/report）。
  # 新規の承認質問ステップを Flow に追加しないことを担保する。
  local steps
  steps=$(sed -n '/^## Flow/,/^## Responsibility Boundary/p' "$MERGE" | grep -cE '^[0-9]+\. ')
  [ "$steps" -eq 5 ]
}
