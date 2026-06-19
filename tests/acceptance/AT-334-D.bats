#!/usr/bin/env bats
# @covers: docs/methodology/autopilot-iron-law.md, rules/atdd-kit.md
# AT-334-D: 効率は test-first 逸脱の理由にしない（C2）
#
# lifecycle: [regression]

IRON_LAW="docs/methodology/autopilot-iron-law.md"
RULES="rules/atdd-kit.md"

# --- AT-334-D1: iron-law に効率逸脱禁止が正典として明記 ---

@test "AT-334-D1a: iron-law contains prohibition against efficiency as justification for test-first deviation" {
  # Given: docs/methodology/autopilot-iron-law.md
  # When: 該当節を読む
  # Then: 効率（session limit / トークン / 速さ）が test-first 逸脱の理由にならないことが明記されている
  run grep -qiE '効率|efficiency|session.*limit|token|speed|速さ' "$IRON_LAW"
  [ "$status" -eq 0 ]
}

@test "AT-334-D1b: iron-law explicitly mentions test-first deviation (red skip) prohibition" {
  # Given: docs/methodology/autopilot-iron-law.md
  # When: 該当節を読む
  # Then: test-first 逸脱（red 先行スキップを含む）の禁止が記述されている
  run grep -qiE 'test.*first.*逸脱|逸脱.*test.*first|red.*skip|skip.*red|test-first.*deviation|deviation.*test-first' "$IRON_LAW"
  [ "$status" -eq 0 ]
}

# --- AT-334-D2: rules が正典を参照しつつバジェット維持 ---

@test "AT-334-D2a: rules/atdd-kit.md references test-first deviation prohibition" {
  # Given: rules/atdd-kit.md の Iron Laws / Workflow 節
  # When: Iron Laws / Workflow 節を読む
  # Then: 効率逸脱禁止の参照が存在する
  run grep -qiE '効率.*逸脱|逸脱.*効率|efficiency.*deviation|test-first.*overrid|iron.*law.*efficiency|autopilot-iron-law' "$RULES"
  [ "$status" -eq 0 ]
}

@test "AT-334-D2b: rules/atdd-kit.md line count stays at or below 60 (invariant budget)" {
  # Given: rules/atdd-kit.md
  # When: 行数を数える
  # Then: 60 行以下（行数バジェット invariant — 数値ピンではなく上限チェック）
  local n
  n=$(wc -l < "$RULES" | tr -d ' ')
  [ "$n" -le 60 ]
}
