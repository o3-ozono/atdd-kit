#!/usr/bin/env bats
# @covers: lib/autopilot_convergence.sh, skills/autopilot/SKILL.md
# AT-334-A: 決定的 red ゲート（F1 / C1）
#
# 新規 AT について red 証跡が無い限り impl phase の satisfaction oracle が満たされないことを、
# LLM 判断ではなく exit code で機械検証する。
#
# lifecycle: [draft]

setup() {
  LIB="lib/autopilot_convergence.sh"
  source "$LIB"
  TMP="$(mktemp -d)"
  RED_JSONL="$TMP/red.jsonl"
  TEST_COMMIT="abc1234"
  IMPL_COMMIT="def5678"
}

teardown() {
  rm -rf "$TMP"
}

# --- AT-334-A1: red 証跡ありで check_red_evidence exit 0 ---

@test "AT-334-A1: red evidence present and commit order correct returns exit 0" {
  # Given: test コミットが impl コミットより先行し、test コミット時点の red 証跡が記録済み
  record_red_evidence "$RED_JSONL" "$TEST_COMMIT" "tests/acceptance/AT-334-A.bats"
  # When: check_red_evidence を実行する
  run check_red_evidence "$TEST_COMMIT" "$IMPL_COMMIT" "$RED_JSONL"
  # Then: exit 0（redObserved を真にできる）
  [ "$status" -eq 0 ]
}

# --- AT-334-A2: red 証跡欠如で fail-closed ---

@test "AT-334-A2: missing red evidence returns non-zero exit (fail-closed)" {
  # Given: red 証跡が記録されていない（red を一度も踏まず green になった）
  # When: check_red_evidence を実行する（空の red.jsonl）
  run check_red_evidence "$TEST_COMMIT" "$IMPL_COMMIT" "$RED_JSONL"
  # Then: 非 0 exit（satisfaction oracle の redObserved 項が false になる）
  [ "$status" -ne 0 ]
}

# --- AT-334-A3: コミット順序逆転で fail-closed ---

@test "AT-334-A3: evidence recorded for a different commit does not satisfy check_red_evidence (wrong test_sha)" {
  # Given: test コミット(TEST_COMMIT)とは別コミット(IMPL_COMMIT)の証跡しか存在しない
  # （impl より先に test が red だった証跡を持つ）
  record_red_evidence "$RED_JSONL" "$IMPL_COMMIT" "tests/acceptance/AT-334-A.bats"
  # When: check_red_evidence に TEST_COMMIT を渡す（IMPL_COMMIT の証跡は存在するが TEST_COMMIT には無い）
  run check_red_evidence "$TEST_COMMIT" "$IMPL_COMMIT" "$RED_JSONL"
  # Then: 非 0 exit（TEST_COMMIT の red 証跡が無いため fail-closed）
  [ "$status" -ne 0 ]
}

# --- AT-334-A4: 空入力・破損入力は fail-closed ---

@test "AT-334-A4a: empty test-commit arg returns non-zero exit" {
  # Given: test コミット引数が空
  run check_red_evidence "" "$IMPL_COMMIT" "$RED_JSONL"
  # Then: 非 0 exit（fail-safe）
  [ "$status" -ne 0 ]
}

@test "AT-334-A4b: empty impl-commit arg returns non-zero exit" {
  # Given: impl コミット引数が空
  run check_red_evidence "$TEST_COMMIT" "" "$RED_JSONL"
  # Then: 非 0 exit（fail-safe）
  [ "$status" -ne 0 ]
}

@test "AT-334-A4c: record_red_evidence refuses empty commit (same fail-closed as record_iteration)" {
  # Given: コミット引数が空
  run record_red_evidence "$RED_JSONL" "" "tests/acceptance/AT-334-A.bats"
  # Then: 非 0 exit、ファイルに書き込まれない
  [ "$status" -ne 0 ]
  [ ! -s "$RED_JSONL" ]
}

@test "AT-334-A4d: record_red_evidence refuses commit with newline (would split JSONL)" {
  # Given: コミット引数に改行が含まれる（破損）
  run record_red_evidence "$RED_JSONL" "$(printf 'abc\ndef')" "tests/acceptance/AT-334-A.bats"
  # Then: 非 0 exit（破損行を書き込まない）
  [ "$status" -ne 0 ]
  [ ! -s "$RED_JSONL" ]
}

@test "AT-334-A4e: record_red_evidence refuses commit with double-quote (would forge JSON)" {
  # Given: コミット引数に引用符が含まれる（破損）
  run record_red_evidence "$RED_JSONL" 'abc"def' "tests/acceptance/AT-334-A.bats"
  # Then: 非 0 exit（破損行を書き込まない）
  [ "$status" -ne 0 ]
  [ ! -s "$RED_JSONL" ]
}

# --- AT-334-A5: satisfaction oracle が 5 項 AND で redObserved を含む ---

@test "AT-334-A5: SKILL.md satisfaction oracle includes redObserved term" {
  # Given: skills/autopilot/SKILL.md の impl phase オラクル定義
  # When: オラクル式を読む
  # Then: redObserved が含まれ、5 項 AND になっている
  run grep -q 'redObserved' skills/autopilot/SKILL.md
  [ "$status" -eq 0 ]
}

@test "AT-334-A5b: SKILL.md states red gate is the symmetric counterpart to the AL-3 green gate" {
  # Given: skills/autopilot/SKILL.md
  # When: 決定的 red ゲートの節を読む
  # Then: red ゲートが AL-3 green ゲートの対であることが記述されている
  run grep -qiE 'red.*gate.*AL-3|AL-3.*red.*gate|red.*green.*symmetric|symmetric.*red.*green' skills/autopilot/SKILL.md
  [ "$status" -eq 0 ]
}
