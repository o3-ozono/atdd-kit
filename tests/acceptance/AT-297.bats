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

# --- AT-003: reviewScope impl 分岐にスコープ外パス P0 検出指示が存在する（US-3） ---

@test "AT-003 US-3: reviewScope impl branch contains out-of-scope path P0 finding instruction" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: skills/autopilot/SKILL.md の reviewScope(step) の PHASE === 'impl' 分岐文字列を検査する
  # Then: impl scope 文に「当該 Issue スコープ外パスへの変更（特に pyproject.toml / CI 設定 / 他 Issue のソース）
  #       を検出したら P0 finding として返す」旨が grep ヒットする
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # reviewScope が存在することを確認する
  grep -qF 'reviewScope' "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: reviewScope が skills/autopilot/SKILL.md に存在しない"
    return 1
  }

  # impl scope 文に P0 finding 相当語が含まれることを確認する（Scope: the impl… 行に P0 が含まれる）
  grep -qE "Scope:.*impl.*P0|Scope.*impl.*[Pp]0 finding" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: reviewScope の impl scope 文に P0 finding 相当語が存在しない"
    return 1
  }

  # impl scope 文に pyproject.toml / CI / スコープ外パス相当語が含まれることを確認する
  grep -qE "pyproject\.toml|out-of-scope path|foreign path|スコープ外" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: reviewScope impl scope 文に pyproject.toml / CI / スコープ外パス相当語が存在しない"
    return 1
  }

  # design 分岐（US/plan scope 文）にスコープ外 P0 文言が混入していないことを確認する
  # design 分岐文字列は "judge ONLY prd.md" または "judge the planning set" を含む行に限定して確認する
  if grep -E "judge ONLY prd\.md|judge the planning set" "${repo_root}/skills/autopilot/SKILL.md" \
      | grep -qE "pyproject\.toml|P0.*foreign|foreign.*P0"; then
    echo "FAIL: design 分岐に impl scope 文の pyproject.toml / P0 foreign 文言が混入している"
    return 1
  fi
  return 0
}

# --- AT-004: oracle が P0/P1 ブロッキング判定式を維持する（US-3 / 非退行不変条件） ---

@test "AT-004 US-3: satisfaction oracle blocking check is unchanged (P0/P1 gate)" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: skills/autopilot/SKILL.md の satisfaction oracle 収束判定式を検査する
  # Then: overall_correctness === 'correct' かつ blocking.length === 0 の判定式が存在し、
  #       混入 P0 finding が green 判定を阻止する経路が維持されている
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  grep -qE "overall_correctness === 'correct'" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: overall_correctness === 'correct' の判定式が存在しない"
    return 1
  }

  grep -qE "blocking\.length === 0" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: blocking.length === 0 の判定式が存在しない"
    return 1
  }

  grep -qE "priorityOf\(f\) <= 1" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: priorityOf(f) <= 1 のフィルタ式が存在しない"
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

@test "AT-006 CS-1: reviewScope has both impl and design branches" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: skills/autopilot/SKILL.md の reviewScope 関数を検査する
  # Then: impl 分岐と design 分岐の両方が存在し、分岐構造が維持されている
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # impl 分岐（PHASE === 'impl'）の存在確認
  grep -qE "PHASE === 'impl'" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: reviewScope の impl 分岐（PHASE === 'impl'）が存在しない"
    return 1
  }

  # design 分岐の存在確認（design phase の説明文 = US/plan scope 文）
  grep -qE "Scope \(design phase\)" "${repo_root}/skills/autopilot/SKILL.md" || {
    echo "FAIL: reviewScope の design 分岐（Scope (design phase)）が存在しない"
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
