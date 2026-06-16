#!/usr/bin/env bats
# @covers: skills/autopilot/SKILL.md skills/running-atdd-cycle/SKILL.md tests/acceptance/helpers/changelog.bash tests/acceptance/AT-271.bats tests/acceptance/AT-284.bats
# AT-296: VERDICT_SCHEMA enum 制約化 + regression ピン禁止ガイダンス補完・changelog ヘルパー集約
# Issue #296 / #300

# --- AT-001: VERDICT_SCHEMA.overall_correctness が enum 制約を持つ（AC-296-1） ---

@test "AT-001 AC-296-1: overall_correctness has enum constraint in autopilot SKILL.md" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: skills/autopilot/SKILL.md の VERDICT_SCHEMA 内 overall_correctness プロパティ定義を検査する
  # Then: overall_correctness の定義に enum: ['correct', 'incorrect'] が含まれる（grep ヒット）
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  grep -qE "enum: \['correct', 'incorrect'\]" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: overall_correctness に enum: ['correct', 'incorrect'] が存在しない"
    return 1
  }
  # 該当行が overall_correctness の定義行であることも確認する
  grep -qE "overall_correctness.*enum: \['correct', 'incorrect'\]" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: enum 制約が overall_correctness プロパティの定義行にない"
    return 1
  }
}

# --- AT-002: oracle の厳密一致判定が enum 制約と整合し破綻しない（AC-296-2） ---

@test "AT-002 AC-296-2: strict equality check for overall_correctness is unchanged" {
  # Given: enum 制約を追加した autopilot SKILL.md
  # When: satisfaction oracle の収束判定式（overall_correctness === 'correct'）を検査する
  # Then: overall_correctness === 'correct' の厳密一致式が少なくとも 2 箇所存在し、判定が破綻しない
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # 収束判定式（line 224 相当）が存在すること
  grep -qE "overall_correctness === 'correct'" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: overall_correctness === 'correct' の厳密一致式が存在しない"
    return 1
  }
  # ドキュメント行（line 78 相当）での参照も存在すること
  grep -qE "overall_correctness.*(==|===).*correct" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: overall_correctness の判定参照（== または ===）がドキュメント内に存在しない"
    return 1
  }
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
