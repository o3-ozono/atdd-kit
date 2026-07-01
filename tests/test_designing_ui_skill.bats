#!/usr/bin/env bats
# @covers: skills/designing-ui/SKILL.md
# @covers: docs/methodology/designing-ui-doc1.md
# @covers: docs/methodology/designing-ui-doc2.md
# Acceptance Test for the designing-ui skill (#368).
# Per `docs/methodology/acceptance-test-feasibility.md` and #355 F4, this is a
# skill/doc change — the AT modality is BATS pins asserting SKILL.md / doc
# content rather than an executable tests/acceptance/ scenario. Each @test
# below corresponds to one AT-368-N entry in
# docs/issues/368-designing-ui-flow/acceptance-tests.md.

SKILL_FILE="skills/designing-ui/SKILL.md"
DOC1_FILE="docs/methodology/designing-ui-doc1.md"
DOC2_FILE="docs/methodology/designing-ui-doc2.md"

# --- AT-368-1: frontmatter / launchability (US-1) --------------------------

@test "AT-368-1: SKILL.md exists with name: designing-ui and Use-when description" {
  [ -f "$SKILL_FILE" ]
  grep -q '^name: designing-ui$' "$SKILL_FILE"
  local desc
  desc=$(grep '^description:' "$SKILL_FILE" | sed 's/^description:[[:space:]]*//' | tr -d '"')
  [[ "$desc" == "Use when"* ]]
}

# --- AT-368-2: UI 要件フェーズ成果物 (US-2) ---------------------------------

@test "AT-368-2: SKILL.md defines ui-requirements.md and the UI-requirements phase" {
  grep -qF 'docs/issues/<NNN>/ui-requirements.md' "$SKILL_FILE"
  grep -qE 'UI (要件|Requirements)' "$SKILL_FILE"
  grep -qE '機能要件' "$SKILL_FILE"
}

# --- AT-368-3: 情報設計フェーズ成果物 (US-3) --------------------------------

@test "AT-368-3: SKILL.md defines information-architecture.md and screen-unit-before-wireframe rule" {
  grep -qF 'docs/issues/<NNN>/information-architecture.md' "$SKILL_FILE"
  grep -qE '情報設計' "$SKILL_FILE"
  grep -qE '画面の?単位.*(確定|固め)' "$SKILL_FILE"
}

# --- AT-368-4: ワイヤーフレームフェーズ成果物 (US-4) ------------------------

@test "AT-368-4: SKILL.md defines wireframes.md and no-decoration skeleton rule" {
  grep -qF 'docs/issues/<NNN>/wireframes.md' "$SKILL_FILE"
  grep -qE 'ワイヤーフレーム' "$SKILL_FILE"
  grep -qE '装飾.*(含めない|なし)' "$SKILL_FILE"
}

# --- AT-368-5: ビジュアル方針フェーズ成果物 (US-5) --------------------------

@test "AT-368-5: SKILL.md defines visual-policy.md and platform/design-system rationale" {
  grep -qF 'docs/issues/<NNN>/visual-policy.md' "$SKILL_FILE"
  grep -qE 'ビジュアル方針' "$SKILL_FILE"
  grep -q 'HIG' "$SKILL_FILE"
  grep -q 'Material' "$SKILL_FILE"
}

# --- AT-368-6: 実装連携フェーズ成果物 (US-6) --------------------------------

@test "AT-368-6: SKILL.md defines implementation-handoff.md and handoff granularity" {
  grep -qF 'docs/issues/<NNN>/implementation-handoff.md' "$SKILL_FILE"
  grep -qE '実装連携' "$SKILL_FILE"
  grep -qE 'コンポーネント' "$SKILL_FILE"
  grep -qE 'トークン' "$SKILL_FILE"
}

# --- AT-368-7: 引き出し型 5 フェーズ順序 (US-7) -----------------------------

@test "AT-368-7: SKILL.md drives the 5 phases in order as a pull-style dialogue" {
  local order
  order=$(grep -nE 'UI 要件確認|情報設計|ワイヤーフレーム|ビジュアル方針|実装連携' "$SKILL_FILE" | cut -d: -f1)
  local n
  n=$(echo "$order" | wc -l | tr -d ' ')
  [ "$n" -ge 5 ]
  # phases must appear in ascending line-number order
  [ "$(echo "$order" | sort -n)" = "$order" ]
  grep -qE '引き出し型|pull' "$SKILL_FILE"
}

# --- AT-368-8: doc1 存在と骨格規律 (US-8) -----------------------------------

@test "AT-368-8: doc1 exists and documents UI-requirements/IA/wireframe skeleton discipline (no decoration)" {
  [ -f "$DOC1_FILE" ]
  grep -qE 'UI (要件|Requirements)' "$DOC1_FILE"
  grep -qE '情報設計' "$DOC1_FILE"
  grep -qE 'ワイヤーフレーム' "$DOC1_FILE"
  grep -qE '装飾.*(含めない|なし)' "$DOC1_FILE"
}

# --- AT-368-9: doc2 存在とビジュアル/実装連携規律 (US-9) --------------------

@test "AT-368-9: doc2 exists and documents visual policy / platform conventions / handoff discipline" {
  [ -f "$DOC2_FILE" ]
  grep -qE 'ビジュアル方針' "$DOC2_FILE"
  grep -q 'HIG' "$DOC2_FILE"
  grep -q 'Material Design' "$DOC2_FILE"
  grep -q 'Baseline' "$DOC2_FILE"
  grep -qE 'Design system' "$DOC2_FILE"
  grep -qE '実装連携' "$DOC2_FILE"
}

# --- AT-368-10: writing-design-doc との住み分け (US-10) --------------------

@test "AT-368-10: SKILL.md states the Responsibility Boundary against writing-design-doc" {
  grep -q '## Responsibility Boundary' "$SKILL_FILE"
  grep -q 'writing-design-doc' "$SKILL_FILE"
  grep -qE 'AT.*(生成しない|実装.*担わない)|担わない.*AT' "$SKILL_FILE"
}

# --- AT-368-11: 概念とプラットフォーム作法の分離 (CS-1) ---------------------

@test "CS-1: core-thesis separation (concept=product, convention=platform, dokuji marker) in SKILL.md" {
  grep -qE 'プロダクト側' "$SKILL_FILE"
  grep -qE 'プラットフォーム' "$SKILL_FILE"
  grep -qF '[独自]' "$SKILL_FILE"
}

# --- AT-368-12: アクセシビリティの横串適用 (CS-2) ---------------------------

@test "CS-2: accessibility is a cross-phase concern from the wireframe phase onward" {
  for f in "$SKILL_FILE" "$DOC2_FILE"; do
    grep -q 'WAI-ARIA' "$f"
    grep -q 'WCAG 2.2' "$f"
    grep -q 'JIS Z 8520' "$f"
  done
  grep -qE 'ワイヤー.*(組み込|から)' "$SKILL_FILE"
}

# --- AT-368-13: designing-ui のスコープ限定 (CS-3) --------------------------

@test "CS-3: SKILL.md scopes out code/AT implementation and Plan authoring" {
  grep -qE 'コード実装' "$SKILL_FILE"
  grep -qE 'Acceptance Test' "$SKILL_FILE"
  grep -qE 'Plan.*(担わない|作成しない)' "$SKILL_FILE"
}

# --- AT-368-14: 成果物配置と命名の一貫性 (CS-4) ------------------------------

@test "CS-4: all 5 deliverable paths use the approved naming under docs/issues/<NNN>/" {
  for path in ui-requirements information-architecture wireframes visual-policy implementation-handoff; do
    grep -qF "docs/issues/<NNN>/${path}.md" "$SKILL_FILE"
  done
  [ -f "$DOC1_FILE" ]
  [ -f "$DOC2_FILE" ]
}

# --- AT-368-15: 構造検証 BATS pin 自己言及 (CS-5) ---------------------------

@test "AT-368-15: SKILL.md and both methodology docs exist (structural pin)" {
  [ -f "$SKILL_FILE" ]
  [ -f "$DOC1_FILE" ]
  [ -f "$DOC2_FILE" ]
}

# --- Integration -------------------------------------------------------------

@test "integration: SKILL.md has Upstream (defining-requirements) and Downstream (writing-plan-and-tests)" {
  grep -q '^## Integration' "$SKILL_FILE"
  grep -qE '\*\*Upstream:\*\*.*defining-requirements' "$SKILL_FILE"
  grep -qE '\*\*Downstream:\*\*.*writing-plan-and-tests' "$SKILL_FILE"
}

# --- Session Start Check ------------------------------------------------------

@test "session-start: SKILL.md includes a Session Start Check section" {
  grep -q 'Session Start Check' "$SKILL_FILE"
}

# --- Persona-less invariant ----------------------------------------------------

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}

# --- Line budget ---------------------------------------------------------------

@test "line budget: SKILL.md is at most 200 lines (#216 PRD design rule)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 200 ]
}

# --- Output language -------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}
