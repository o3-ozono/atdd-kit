#!/usr/bin/env bats
# @covers: skills/defining-requirements/SKILL.md
#
# Acceptance Tests for Issue #365 -- defining-requirements に
# 引き出し型対話ディシプリンを追加する Iron Law ブロック。
#
# キーフレーズ grep のみ（論理順序の検証は行わない）。
# #289: version・日付・行数を exact-pin しない。

bats_require_minimum_version 1.5.0

SKILL_FILE="skills/defining-requirements/SKILL.md"

# --- AT-365-1: Iron Law block presence and single placement in Flow (F1) ---

@test "AT-365-1: Iron Law heading appears exactly once" {
  local n
  n=$(grep -c '^## Iron Law: 対話ディシプリン' "$SKILL_FILE")
  [ "$n" -eq 1 ]
}

@test "AT-365-1: Iron Law heading is placed after the Flow section" {
  local flow_line iron_line
  flow_line=$(grep -n '^## Flow' "$SKILL_FILE" | head -1 | cut -d: -f1)
  iron_line=$(grep -n '^## Iron Law: 対話ディシプリン' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$flow_line" ] && [ -n "$iron_line" ]
  [ "$flow_line" -lt "$iron_line" ]
}

# --- AT-365-2: Discipline 1 "one question per turn" (F1) -------------------

@test "AT-365-2: one-question-per-turn discipline and primary source Rocket Surgery Made Easy are documented" {
  grep -q '1 ターン 1 問' "$SKILL_FILE"
  grep -q 'Rocket Surgery Made Easy' "$SKILL_FILE"
}

# --- AT-365-3: Discipline 2 elicitation HARD-GATE / no-proposal-completion (F2) ---

@test "AT-365-3: proposal-completion HARD-GATE ban and the method-domain exception boundary are documented" {
  grep -q '提案完成型' "$SKILL_FILE"
  grep -q 'HARD-GATE' "$SKILL_FILE"
  grep -q '手法' "$SKILL_FILE"
}

# --- AT-365-4: Discipline 3 dialogue vocabulary constraint (C1) ------------

@test "AT-365-4: vocabulary-constraint discipline, verbatim-quote, and plain-language phrasing are documented" {
  grep -q '語彙制約' "$SKILL_FILE"
  grep -q 'そのまま引用' "$SKILL_FILE"
  grep -q '平易な言葉' "$SKILL_FILE"
}

# --- AT-365-5: Discipline 4 automatic rationale recording (C2) -------------

@test "AT-365-5: rationale-recording discipline, PRD-body persistence, and no-commit-message-dependency are documented" {
  grep -q '経緯記録' "$SKILL_FILE"
  grep -q 'PRD 本体' "$SKILL_FILE"
  grep -qi 'commit message' "$SKILL_FILE"
}

# --- AT-365-6: Discipline 5 Wall detection + send-back template (F3) ------

@test "AT-365-6: Wall detection discipline and its 3 signals are documented" {
  grep -q 'Wall 検知' "$SKILL_FILE"
  grep -q '層化要素の欠如' "$SKILL_FILE"
  grep -q '情報量の極端な低下' "$SKILL_FILE"
  grep -q '別語再陳述' "$SKILL_FILE"
}

@test "AT-365-6: the one-deepening-then-send-back trigger condition is documented" {
  grep -q '1 回深掘り' "$SKILL_FILE"
  grep -q '上流の壁打ちへ戻す' "$SKILL_FILE"
}

@test "AT-365-6: the send-back wording template and signal-annotation instruction are documented" {
  grep -q 'もう少し具体化するところから始めてみましょうか' "$SKILL_FILE"
  grep -q 'どのシグナルが発動したかを本文中で補足' "$SKILL_FILE"
}

# --- AT-365-7: Discipline 6 target stratification follow-up (F4) ----------

@test "AT-365-7: target-stratification follow-up discipline, its prompt, and the once-only constraint are documented" {
  grep -q '層化追問' "$SKILL_FILE"
  grep -q '強いて言うと誰' "$SKILL_FILE"
  grep -q '1 回だけ' "$SKILL_FILE"
}

# --- AT-365-8: pin test existence and non-regression (F5) ------------------

@test "AT-365-8: AT-365.bats itself exists (self-referential pin)" {
  [ -f "tests/acceptance/AT-365.bats" ]
}

# --- AT-365-9: version bump + CHANGELOG alignment (invariant / F6) --------

@test "AT-365-9: plugin.json version matches the newest CHANGELOG release heading" {
  local plugin_version changelog_version
  plugin_version=$(grep -m1 '"version"' .claude-plugin/plugin.json | sed -E 's/.*"version": *"([^"]+)".*/\1/')
  changelog_version=$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | sed -E 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/')
  [ -n "$plugin_version" ]
  [ -n "$changelog_version" ]
  [ "$plugin_version" = "$changelog_version" ]
}

@test "AT-365-9: CHANGELOG Added section contains a #365 Iron Law entry" {
  grep -q '#365' CHANGELOG.md
  grep -A5 '^### Added' CHANGELOG.md | grep -q 'Iron Law'
}
