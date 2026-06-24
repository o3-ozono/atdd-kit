#!/usr/bin/env bats
# @covers: skills/autopilot/SKILL.md skills/running-atdd-cycle/SKILL.md tests/acceptance/helpers/changelog.bash tests/acceptance/AT-271.bats tests/acceptance/AT-284.bats
# AT-296: VERDICT_SCHEMA enum 制約化 + regression ピン禁止ガイダンス補完・changelog ヘルパー集約
# Issue #296 / #300

# --- AT-001: 収束オラクルが客観ゲートのみで構成される（AC-296-1, #355 supersedes original #296） ---
#
# #355/#359 redesign: autopilot の収束ループは客観ゲートのみに一本化され、LLM-reviewer は
# ループから完全除去された。原 #296 の VERDICT_SCHEMA / overall_correctness の enum 制約は
# 設計上削除済み。本 AT は #355 が #296 の LLM-correctness チェックを置き換えたことを反映し、
# 現行の客観オラクル（objective gate）が SKILL.md に定義されていることを検証する。

@test "AT-001 AC-296-1: convergence oracle is the objective gate (no overall_correctness)" {
  # Given: #355/#359 で客観ゲート一本化された autopilot SKILL.md
  # When: 収束オラクルの定義（objective oracle）を検査する
  # Then: AND(redObserved, atGreen, coverageOk) の客観オラクルが存在し、overall_correctness の
  #       enum 制約は設計上もはや存在しない
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # 客観オラクル定義（#355 F1）が存在すること
  grep -qE "objective oracle.*AND\(redObserved, atGreen, coverageOk\)" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: objective oracle AND(redObserved, atGreen, coverageOk) の定義が存在しない"
    return 1
  }
  # 原 #296 の overall_correctness の enum 制約は #355 で削除済みであること（再混入防止）
  if grep -qE "overall_correctness.*enum: \['correct', 'incorrect'\]" "${repo_root}/skills/autopilot/SKILL.md"; then
    echo "FAIL: overall_correctness の enum 制約が再混入している（#355 で削除済みのはず）"
    return 1
  fi
}

# --- AT-002: 収束判定式が客観ゲートの AND であり LLM-review 項を含まない（AC-296-2, #355 supersedes original #296） ---

@test "AT-002 AC-296-2: converged is AND of objective gates with no LLM-review term" {
  # Given: 客観ゲート一本化された autopilot SKILL.md
  # When: 収束判定式（const converged = ...）を検査する
  # Then: converged = redObserved && atGreen && coverageOk の厳密一致式が存在し、
  #       overall_correctness などの LLM-review 項は判定式に含まれない（#355 AT-355-F1 と同主旨）
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # 収束判定式が客観ゲートの AND であること
  grep -qE "const converged = redObserved && atGreen && coverageOk" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: converged = redObserved && atGreen && coverageOk の収束判定式が存在しない"
    return 1
  }
  # 客観オラクルに LLM-review 項がない旨が明記されていること（#355 F1）
  grep -qE "No LLM-review term" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: 'No LLM-review term'（LLM-review 項なし）の明記が存在しない"
    return 1
  }
  # 原 #296 の overall_correctness === 'correct' 厳密一致式は判定式から削除済みであること
  if grep -qE "overall_correctness === 'correct'" "${repo_root}/skills/autopilot/SKILL.md"; then
    echo "FAIL: overall_correctness === 'correct' が収束判定に残存している（#355 で削除済みのはず）"
    return 1
  fi
}

# --- AT-003: running-atdd-cycle に時点依存ピン禁止ガイダンスが存在する（AC-300-1） ---

@test "AT-003 AC-300-1: running-atdd-cycle SKILL.md has point-in-time pin prohibition guidance" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: skills/running-atdd-cycle/SKILL.md の [regression] 確立箇所（C2 バレット）を検査する
  # Then: [regression] AT が時点依存値を完全一致でピンせず、履歴事実＋整合事実で表現する旨が grep 可能
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  grep -qE "#289" "${repo_root}/skills/running-atdd-cycle/SKILL.md" || {
    echo "FAIL: running-atdd-cycle/SKILL.md に #289 参照（時点依存ピン禁止ガイダンス）が存在しない"
    return 1
  }
}

# --- AT-004: ガイダンス文言が writing-plan-and-tests と整合している（AC-300-2） ---

@test "AT-004 AC-300-2: both skills share aligned pin-prohibition guidance with #289 ref" {
  # Given: running-atdd-cycle と writing-plan-and-tests の両 SKILL.md
  # When: 両ファイルの再発防止ガイダンス文言（#289 参照）を突き合わせる
  # Then: 用語・主旨が整合し、#289 参照を含む同主旨のガイダンスが両スキルに存在する
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  grep -q "#289" "${repo_root}/skills/running-atdd-cycle/SKILL.md" || {
    echo "FAIL: running-atdd-cycle/SKILL.md に #289 参照がない"
    return 1
  }
  grep -q "#289" "${repo_root}/skills/writing-plan-and-tests/SKILL.md" || {
    echo "FAIL: writing-plan-and-tests/SKILL.md に #289 参照がない"
    return 1
  }
}

# --- AT-005: changelog_latest_release ヘルパーが定義されている（AC-300-3） ---

@test "AT-005 AC-300-3: helpers/changelog.bash provides changelog_latest_release function" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: tests/acceptance/helpers/changelog.bash を source し changelog_latest_release CHANGELOG.md を実行する
  # Then: 関数が ## [Unreleased] をスキップして先頭の ## [X.Y.Z] から X.Y.Z を出力し、plugin.json version と一致する
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  [[ -f "${repo_root}/tests/acceptance/helpers/changelog.bash" ]] || {
    echo "FAIL: tests/acceptance/helpers/changelog.bash が存在しない"
    return 1
  }

  # shellcheck disable=SC1090
  source "${repo_root}/tests/acceptance/helpers/changelog.bash"

  local top
  top=$(changelog_latest_release "${repo_root}/CHANGELOG.md")
  [[ -n "$top" ]] || {
    echo "FAIL: changelog_latest_release が空文字を返した"
    return 1
  }

  # plugin.json version と一致することを確認する（不変条件）
  local version
  version=$(grep '"version"' "${repo_root}/.claude-plugin/plugin.json" | grep -o '"[0-9.]*"' | tr -d '"')
  [[ "$top" == "$version" ]] || {
    echo "FAIL: changelog_latest_release の出力 (${top}) が plugin.json version (${version}) と一致しない"
    return 1
  }
}

# --- AT-006: AT-271/AT-284 のインライン抽出重複が解消されている（AC-300-4） ---

@test "AT-006 AC-300-4: AT-271.bats uses helper, no inline extraction pattern remains" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: tests/acceptance/AT-271.bats を検査する
  # Then: changelog_latest_release 呼び出しが存在し、grep -oE インライン抽出が残っていない
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  grep -q "changelog_latest_release" "${repo_root}/tests/acceptance/AT-271.bats" || {
    echo "FAIL: AT-271.bats に changelog_latest_release 呼び出しがない"
    return 1
  }
  if grep -qF "grep -oE '^## \[" "${repo_root}/tests/acceptance/AT-271.bats"; then
    echo "FAIL: AT-271.bats にインライン抽出パターン（grep -oE '^## \['）が残っている"
    return 1
  fi
}

@test "AT-006 AC-300-4: AT-284.bats uses helper, no inline extraction pattern remains" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: tests/acceptance/AT-284.bats を検査する
  # Then: changelog_latest_release 呼び出しが存在し、grep -oE インライン抽出が残っていない
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  grep -q "changelog_latest_release" "${repo_root}/tests/acceptance/AT-284.bats" || {
    echo "FAIL: AT-284.bats に changelog_latest_release 呼び出しがない"
    return 1
  }
  if grep -qF "grep -oE '^## \[" "${repo_root}/tests/acceptance/AT-284.bats"; then
    echo "FAIL: AT-284.bats にインライン抽出パターン（grep -oE '^## \['）が残っている"
    return 1
  fi
}

# --- AT-007: regression suite が green を維持する（AC-COM-1） ---

@test "AT-007 AC-COM-1: AT-271.bats and AT-284.bats exist for regression coverage" {
  # Given: 本 Issue の全変更を適用した作業ツリー
  # When: regression suite の主要ファイルの存在を確認する
  # Then: AT-271.bats / AT-284.bats が存在し suite の健全性が保たれている
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  [[ -f "${repo_root}/tests/acceptance/AT-271.bats" ]] || {
    echo "FAIL: AT-271.bats が存在しない"
    return 1
  }
  [[ -f "${repo_root}/tests/acceptance/AT-284.bats" ]] || {
    echo "FAIL: AT-284.bats が存在しない"
    return 1
  }
}

# --- AT-008: version bump ＋ CHANGELOG エントリがリリース規約に従う（AC-COM-2） ---

@test "AT-008 AC-COM-2: plugin.json version matches topmost CHANGELOG release heading" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: .claude-plugin/plugin.json の version と changelog_latest_release の出力を突き合わせる
  # Then: version が SemVer で bump され、CHANGELOG の最新リリース見出しと完全一致する（特定 version 値をピンしない不変条件）
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  [[ -f "${repo_root}/tests/acceptance/helpers/changelog.bash" ]] || {
    echo "FAIL: tests/acceptance/helpers/changelog.bash が存在しない"
    return 1
  }

  # shellcheck disable=SC1090
  source "${repo_root}/tests/acceptance/helpers/changelog.bash"

  local top version
  top=$(changelog_latest_release "${repo_root}/CHANGELOG.md")
  version=$(grep '"version"' "${repo_root}/.claude-plugin/plugin.json" | grep -o '"[0-9.]*"' | tr -d '"')

  [[ -n "$top" ]] || {
    echo "FAIL: CHANGELOG に [X.Y.Z] 形式のリリース見出しがない"
    return 1
  }
  [[ -n "$version" ]] || {
    echo "FAIL: plugin.json に version が存在しない"
    return 1
  }
  [[ "$version" == "$top" ]] || {
    echo "FAIL: plugin.json version (${version}) が CHANGELOG 最新リリース見出し (${top}) と一致しない"
    return 1
  }
}
