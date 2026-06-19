#!/usr/bin/env bats
# @covers: skills/running-atdd-cycle/SKILL.md
# AT-334-B: test/impl コミット分離による red→green の機械検証（F2）
#
# running-atdd-cycle の Flow ステップ2（Confirm RED）に、test コミットと impl コミットの
# 分離を必須化する文言が追加されていることを grep で確認する。
#
# lifecycle: [regression]

SKILL_FILE="skills/running-atdd-cycle/SKILL.md"

# --- AT-334-B1: running-atdd-cycle が test/impl コミット分離を必須化する ---

@test "AT-334-B1: SKILL.md Step 2 requires test commit before impl commit (separation mandatory)" {
  # Given: skills/running-atdd-cycle/SKILL.md の Flow（C2 RED-first）
  # When: ステップ2「Confirm RED」周辺を読む
  # Then: test コミットと impl コミットの分離が必須として記述されている
  run grep -qiE 'commit.*separ|separ.*commit|コミット.*分離|分離.*コミット' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "AT-334-B1b: SKILL.md states commit separation provides machine-verifiable red-to-green evidence" {
  # Given: skills/running-atdd-cycle/SKILL.md の C2 説明
  # When: C2 説明を読む
  # Then: コミット履歴から red→green 粒度が機械検証できる根拠であることが明記されている
  run grep -qiE 'machine.*verif|deterministic.*commit|commit.*evidence|コミット.*機械検証|red.*green.*commit|commit.*red.*green' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
