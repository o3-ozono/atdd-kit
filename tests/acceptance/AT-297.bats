#!/usr/bin/env bats
# @covers: skills/autopilot/SKILL.md
# AT-297: autopilot impl phase が並行セッションの未追跡ファイル混入で偽 MAX_ITERATIONS / スコープ汚染を起こす問題の解消
# Issue #297

# --- AT-001: GEN_GUARD に foreign 未追跡ファイル不可触ガード文が存在する（US-1） ---

@test "AT-001 US-1: GEN_GUARD contains foreign-file untouchable guard" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: skills/autopilot/SKILL.md の GEN_GUARD 定数定義を検査する
  # Then: GEN_GUARD 文字列に「自分が作成していない／当該 Issue スコープ外の未追跡・未コミットファイルを
  #       変更・コミット・ゲート回避設定（exclude 等）の対象にしない」旨が grep ヒットする
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # GEN_GUARD 定数が存在することを確認する
  grep -qF 'const GEN_GUARD =' "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: GEN_GUARD 定数が skills/autopilot/SKILL.md に存在しない"
    return 1
  }

  # GEN_GUARD 行に foreign / did not create / スコープ外 相当の文言が含まれることを確認する
  grep -qE "GEN_GUARD = .*(foreign|did not create|outside.*scope|scope.*outside|not your)" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: GEN_GUARD に foreign/did-not-create/スコープ外 相当の文言が存在しない"
    return 1
  }

  # 変更・コミット禁止（exclude 等の回避設定を含む）相当の文言が含まれることを確認する
  grep -qE "GEN_GUARD = .*(do not|never).*(commit|change|modify)|GEN_GUARD = .*exclude" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: GEN_GUARD に 変更・コミット禁止（exclude 等の回避設定含む）相当の文言が存在しない"
    return 1
  }
}

# --- AT-002: GEN_GUARD に COMPLETED_WITH_DEBT エスカレーション指示が存在する（US-2） ---

@test "AT-002 US-2: GEN_GUARD contains COMPLETED_WITH_DEBT escalation instruction for foreign gate failure" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: skills/autopilot/SKILL.md の GEN_GUARD 定数定義を検査する
  # Then: GEN_GUARD 文字列に「foreign ファイル由来でゲートが失敗する場合は修正を試みず
  #       COMPLETED_WITH_DEBT として人間にエスカレーションする」旨が grep ヒットする
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # GEN_GUARD 行に COMPLETED_WITH_DEBT が含まれることを確認する
  grep -qE "GEN_GUARD = .*COMPLETED_WITH_DEBT" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: GEN_GUARD に COMPLETED_WITH_DEBT が存在しない"
    return 1
  }

  # GEN_GUARD 行にエスカレーション相当語が含まれることを確認する
  grep -qE "GEN_GUARD = .*(escalat|human)" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: GEN_GUARD にエスカレーション相当語（escalat / human）が存在しない"
    return 1
  }
}

# --- AT-003: in-loop reviewScope は #355 で除去され収束は客観ゲートのみ（US-3 / #355 が #297 を supersede） ---
# 注: #355 は in-loop LLM レビューをループから完全除去した。これに伴い #297 が導入した
#     in-loop reviewScope（ステップ毎にレビューアをスコープする関数）は概念ごと superseded された。
#     本テストは現行契約（客観オラクルのみ・reviewScope 不在・reviewing-deliverables は standalone）を検証する。

@test "AT-003 US-3: in-loop reviewScope removed by #355 (objective-only convergence)" {
  # Given: 本 Issue の変更を適用した作業ツリー（#355 redesign 適用済み）
  # When: skills/autopilot/SKILL.md の収束機構を検査する
  # Then: in-loop reviewScope は存在せず、収束は客観ゲート AND(redObserved, atGreen, coverageOk) のみで
  #       駆動され、reviewing-deliverables は standalone（ループ外）と明記されている
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # in-loop reviewScope（#297 が導入し #355 が除去）が存在しないことを確認する
  ! grep -qF 'reviewScope' "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: in-loop reviewScope が残存している（#355 で除去されているべき）"
    return 1
  }

  # 収束は客観オラクル AND(redObserved, atGreen, coverageOk) で駆動されることを確認する
  grep -qE "redObserved && atGreen && coverageOk" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: 客観オラクル redObserved && atGreen && coverageOk の収束判定式が存在しない"
    return 1
  }

  # 収束ループに LLM レビュー項がないことが明記されていることを確認する
  grep -qE "No LLM-review term" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: 客観オラクルに 'No LLM-review term' の明記が存在しない"
    return 1
  }

  # reviewing-deliverables が standalone（ループ外）と明記されていることを確認する
  grep -qE "reviewing-deliverables.*(not.*in the loop|standalone|not.*part of.*loop)" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: reviewing-deliverables が standalone（ループ外）と明記されていない"
    return 1
  }
  return 0
}

# --- AT-004: 客観オラクルに LLM レビュー（P0/P1）ブロッキング項が無い（US-3 / #355 が #297 を supersede） ---
# 注: #297 はオラクルの LLM レビュー（overall_correctness / blocking.length / P0/P1 gate）ブロッキング
#     判定を扱っていたが、#355 は in-loop LLM レビューを除去しオラクルを客観項のみに一本化した。
#     本テストは「オラクルに LLM レビュー / ブロッキング項が無い」という現行契約を検証する。

@test "AT-004 US-3: objective oracle has no LLM-review blocking term (P0/P1 removed by #355)" {
  # Given: 本 Issue の変更を適用した作業ツリー（#355 redesign 適用済み）
  # When: skills/autopilot/SKILL.md の収束判定式を検査する
  # Then: 客観項のみ（redObserved / atGreen / coverageOk）で構成され、
  #       LLM レビュー由来のブロッキング判定（overall_correctness / blocking.length / priorityOf<=1）は存在しない
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # 客観オラクルの 3 項が全て存在することを確認する
  grep -qE "redObserved && atGreen && coverageOk" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: 客観オラクル redObserved && atGreen && coverageOk が存在しない"
    return 1
  }

  # LLM レビュー由来のブロッキング判定式が除去されていることを確認する（#355）
  ! grep -qE "overall_correctness === 'correct'" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: overall_correctness === 'correct' が残存している（#355 で除去されているべき）"
    return 1
  }

  ! grep -qE "blocking\.length === 0" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: blocking.length === 0 が残存している（#355 で除去されているべき）"
    return 1
  }

  ! grep -qE "priorityOf\(f\) <= 1" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: priorityOf(f) <= 1 のフィルタ式が残存している（#355 で除去されているべき）"
    return 1
  }
}

# --- AT-005: SKILL.md 行数バジェットが維持される（CS-1 不変条件） ---

@test "AT-005 CS-1: SKILL.md line count stays within budget (le 280, no 3rd raise)" {
  # Given: 本 Issue の guard/critic 追記を適用した作業ツリー
  # When: wc -l skills/autopilot/SKILL.md を実行する
  # Then: 行数が 280 以下（既存 line budget pin と整合・3 回目の raise を発生させない）
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  local line_count
  line_count=$(wc -l < "${repo_root}/skills/autopilot/SKILL.md" | tr -d ' ')

  [[ "$line_count" -le 280 ]] || {
    echo "FAIL: SKILL.md の行数 (${line_count}) が line budget 280 を超えている（3 回目の raise は禁止）"
    return 1
  }
}

# --- AT-006: 既存 autopilot skill 構造不変条件（CS-1） ---

@test "AT-006 CS-1: GEN_GUARD is concatenated into both gen prompts" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: skills/autopilot/SKILL.md の gen 呼び出し構造を検査する
  # Then: GEN_GUARD が両分岐（prevFindings あり / なし）の gen プロンプトに挿入されている
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # GEN_GUARD が approved anchor の後に連結されている形式が 2 箇所存在する
  local n
  n=$(grep -c "approved anchor\.\${GEN_GUARD}" "${repo_root}/skills/autopilot/SKILL.md")
  [[ "$n" -eq 2 ]] || {
    echo "FAIL: GEN_GUARD が両 gen 分岐に連結されている行数が 2 ではない（実際: ${n}）"
    return 1
  }
}

# 注: #355 は in-loop reviewScope（impl/design 分岐でレビューアをスコープする関数）を概念ごと除去した。
#     本テストは「reviewScope は不在で、収束ループには LLM レビューステップが無く、客観ゲートのみ」という
#     現行構造不変条件を検証する（#355 が #297 の in-loop reviewScope を supersede）。
@test "AT-006 CS-1: no in-loop reviewScope; loop is objective-gate-only" {
  # Given: 本 Issue の変更を適用した作業ツリー（#355 redesign 適用済み）
  # When: skills/autopilot/SKILL.md の収束ループ構造を検査する
  # Then: reviewScope は存在せず、ループは generate → objective-gate → fix の客観ゲートのみで構成される
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # in-loop reviewScope が除去されていることを確認する
  ! grep -qF 'reviewScope' "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: in-loop reviewScope が残存している（#355 で除去されているべき）"
    return 1
  }

  # 収束ループが客観ゲート（generate → objective-gate → fix）構造であることを確認する
  grep -qE "generate → objective-gate → fix" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: 収束ループの generate → objective-gate → fix 構造が存在しない"
    return 1
  }

  # 客観オラクルが loop の収束判定であることを確認する
  grep -qE "objective oracle" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: objective oracle の記述が存在しない"
    return 1
  }
}

# --- AT-007: バージョン bump ＋ CHANGELOG がリリース規約に従う（AC-COM） ---

@test "AT-007 AC-COM: plugin.json version matches topmost CHANGELOG release heading" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: .claude-plugin/plugin.json の version と changelog_latest_release を突き合わせる
  # Then: version が SemVer で minor bump され、CHANGELOG 最新リリース見出しと完全一致する
  #       （特定 version 値はピンしない不変条件）
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
