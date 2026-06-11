#!/usr/bin/env bats
# @covers: agents/**
# AT-271: Fixed reviewer agents removal and #234 alignment
# Issue #271

# --- AT-001: 固定 reviewer agent 6 ファイルの削除（US-1） ---

@test "AT-001: six fixed reviewer agent files do not exist" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: agents/{prd,us,plan,code,at,final}-reviewer.md の存在を検査する
  # Then: 6 ファイルすべてが存在せず、agents/ 直下は README.md のみである
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  for f in prd-reviewer.md us-reviewer.md plan-reviewer.md code-reviewer.md at-reviewer.md final-reviewer.md; do
    [[ ! -f "${repo_root}/agents/${f}" ]] || {
      echo "FAIL: 削除済みであるべきファイルが存在する: agents/${f}"
      return 1
    }
  done

  # agents/ 直下は README.md のみであること
  local files
  files=$(ls "${repo_root}/agents/")
  [[ "$files" == "README.md" ]] || {
    echo "FAIL: agents/ 直下が README.md のみでない: ${files}"
    return 1
  }
}

# --- AT-002a: agents/README.md レガシー Usage / 固定 roster の記述が消えている（US-2） ---

@test "AT-002a: agents/README.md has no legacy Usage or fixed roster references" {
  # Given: 再構成後の agents/README.md
  # When: prd-reviewer|... を grep する
  # Then: ヒット 0 件である
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  if grep -qE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|five specialist' \
      "${repo_root}/agents/README.md" 2>/dev/null; then
    echo "FAIL: agents/README.md にレガシー参照が残っている"
    grep -nE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|five specialist' \
      "${repo_root}/agents/README.md" || true
    return 1
  fi
}

# --- AT-002b: agents/README.md に現行実装の 3 点構成が記述されている（US-2） ---

@test "AT-002b: agents/README.md documents three-part structure (custom agent placeholder, model policy, dynamic panel)" {
  # Given: 再構成後の agents/README.md
  # When: 内容を検査する
  # Then: (a) 将来のカスタム agent 置き場、(b) #259 モデルポリシー blockquote、(c) reviewing-deliverables の動的パネル
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  local readme="${repo_root}/agents/README.md"

  # (a) ディレクトリの現行役割（将来のカスタム agent 置き場）
  grep -qi 'custom agent\|将来' "$readme" || {
    echo "FAIL: agents/README.md に将来のカスタム agent 置き場の説明がない"
    return 1
  }

  # (b) #259 モデルポリシー blockquote が存在する（固有文言を確認）
  grep -q 'Sonnet 1.0 : Opus 2.2 : Fable 4.1' "$readme" || {
    echo "FAIL: agents/README.md に #259 モデルポリシーの bench summary 文言がない"
    return 1
  }

  # (c) reviewing-deliverables の動的パネル言及
  grep -qi 'dynamic' "$readme" || {
    echo "FAIL: agents/README.md に動的パネルへの言及がない"
    return 1
  }
}

# --- AT-002c: #259 モデルポリシー pin が無傷である（US-2） ---

@test "AT-002c: test_phase_model_assignment.bats passes all 7 tests" {
  # Given: 再構成後の agents/README.md
  # When: bats tests/test_phase_model_assignment.bats を実行する
  # Then: 7 件すべて green である
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  run bats "${repo_root}/tests/test_phase_model_assignment.bats"
  [[ "$status" -eq 0 ]] || {
    echo "FAIL: test_phase_model_assignment.bats が green でない"
    echo "$output"
    return 1
  }
}

# --- AT-003a: リポジトリ全体のレガシー参照 0 件（US-3） ---

@test "AT-003a: no legacy reviewer references in docs / skills / commands / rules / root docs" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: grep -rE 'prd-reviewer|...' を対象範囲に実行する（docs/issues/ は除外）
  # Then: ヒット 0 件である
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  local hits
  hits=$(grep -rE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer' \
    "${repo_root}/agents/" \
    "${repo_root}/docs/methodology/" \
    "${repo_root}/docs/guides/" \
    "${repo_root}/skills/" \
    "${repo_root}/commands/" \
    "${repo_root}/rules/" \
    "${repo_root}/README.md" \
    "${repo_root}/README.ja.md" \
    "${repo_root}/DEVELOPMENT.md" \
    "${repo_root}/DEVELOPMENT.ja.md" \
    2>/dev/null | \
    grep -v 'AT-271\|test_agents_dynamic_panel' || true)

  [[ -z "$hits" ]] || {
    echo "FAIL: レガシー参照が残っている:"
    echo "$hits"
    return 1
  }
}

# --- AT-003b: 個別文書が動的パネル記述に置換されている（US-3） ---

@test "AT-003b: individual docs replaced with dynamic panel descriptions (no fixed reviewer assumptions)" {
  # Given: 置換後の各ドキュメント
  # When: 旧文言の有無を検査する
  # Then: 固定 reviewer・「specialist reviewer subagents」「47 criteria」前提の記述がない
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # definition-of-ready.md に prd-reviewer への直接言及がない
  if grep -q 'prd-reviewer' "${repo_root}/docs/methodology/definition-of-ready.md"; then
    echo "FAIL: docs/methodology/definition-of-ready.md に prd-reviewer が残っている"
    return 1
  fi

  # getting-started.md に固定 reviewer subagents 前提の記述がない
  if grep -qE 'code-reviewer|at-reviewer|dedicated reviewer subagents' \
      "${repo_root}/docs/guides/getting-started.md" 2>/dev/null; then
    echo "FAIL: docs/guides/getting-started.md に固定 reviewer 参照が残っている"
    return 1
  fi

  # README.md に specialist reviewer / 47 criteria / six specialist がない
  if grep -qE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|47 criteria|six specialist|specialist reviewer' \
      "${repo_root}/README.md" 2>/dev/null; then
    echo "FAIL: README.md にレガシー参照が残っている"
    grep -nE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|47 criteria|six specialist|specialist reviewer' \
      "${repo_root}/README.md" || true
    return 1
  fi

  # README.ja.md に固定 reviewer 参照がない
  if grep -qE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer' \
      "${repo_root}/README.ja.md" 2>/dev/null; then
    echo "FAIL: README.ja.md にレガシー参照が残っている"
    return 1
  fi
}

# --- AT-004a: テスト差し替え — 旧構造テストが削除されている（US-4） ---

@test "AT-004a: tests/test_reviewer_subagents.bats has been deleted" {
  # Given: 本 Issue の変更を適用した作業ツリー
  # When: tests/test_reviewer_subagents.bats の存在を検査する
  # Then: ファイルが存在しない
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  [[ ! -f "${repo_root}/tests/test_reviewer_subagents.bats" ]] || {
    echo "FAIL: tests/test_reviewer_subagents.bats が削除されていない"
    return 1
  }
}

# --- AT-004b: 回帰 pin テストが追加され green である（US-4） ---

@test "AT-004b: tests/test_agents_dynamic_panel_align.bats exists and passes" {
  # Given: 新規 tests/test_agents_dynamic_panel_align.bats
  # When: bats tests/test_agents_dynamic_panel_align.bats を実行する
  # Then: 全 pin が green である
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  [[ -f "${repo_root}/tests/test_agents_dynamic_panel_align.bats" ]] || {
    echo "FAIL: tests/test_agents_dynamic_panel_align.bats が存在しない"
    return 1
  }

  run bats "${repo_root}/tests/test_agents_dynamic_panel_align.bats"
  [[ "$status" -eq 0 ]] || {
    echo "FAIL: test_agents_dynamic_panel_align.bats が green でない"
    echo "$output"
    return 1
  }
}

# --- AT-004c: #105 テストが削除済みファイルを参照していない（US-4） ---

@test "AT-004c: test_issue_105_frontmatter_session_inheritance.bats has no fixed reviewer references and passes" {
  # Given: 更新後の tests/test_issue_105_frontmatter_session_inheritance.bats
  # When: 固定 reviewer 名を grep し、bats で実行する
  # Then: 固定 reviewer 名への参照 0 件かつ全件 green
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  local t="${repo_root}/tests/test_issue_105_frontmatter_session_inheritance.bats"

  if grep -qE 'prd-reviewer|final-reviewer' "$t" 2>/dev/null; then
    echo "FAIL: test_issue_105 に固定 reviewer 参照が残っている"
    grep -nE 'prd-reviewer|final-reviewer' "$t" || true
    return 1
  fi

  run bats "$t"
  [[ "$status" -eq 0 ]] || {
    echo "FAIL: test_issue_105_frontmatter_session_inheritance.bats が green でない"
    echo "$output"
    return 1
  }
}

# --- AT-004d: tests/README.md が同期されている（US-4） ---

@test "AT-004d: tests/README.md has no test_reviewer_subagents row and has test_agents_dynamic_panel_align row" {
  # Given: 更新後の tests/README.md
  # When: テスト一覧表を検査する
  # Then: 旧テストの行がなく、新テストの行がある
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  local readme="${repo_root}/tests/README.md"

  if grep -q 'test_reviewer_subagents' "$readme"; then
    echo "FAIL: tests/README.md に test_reviewer_subagents の行が残っている"
    return 1
  fi

  grep -q 'test_agents_dynamic_panel_align' "$readme" || {
    echo "FAIL: tests/README.md に test_agents_dynamic_panel_align の行がない"
    return 1
  }
}

# --- AT-005: リリース規律（CS-1） ---

@test "AT-005: CHANGELOG has [3.12.0] with Removed section and plugin.json version is 3.12.0" {
  # Given: CHANGELOG.md と .claude-plugin/plugin.json
  # When: 新バージョンエントリと version 値を検査する
  # Then: [3.12.0] に ### Removed エントリがあり、plugin.json の version が 3.12.0
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  grep -q '\[3.12.0\]' "${repo_root}/CHANGELOG.md" || {
    echo "FAIL: CHANGELOG.md に [3.12.0] がない"
    return 1
  }

  grep -A5 '\[3.12.0\]' "${repo_root}/CHANGELOG.md" | grep -q '### Removed' || {
    echo "FAIL: [3.12.0] セクションに ### Removed がない"
    return 1
  }

  local version
  version=$(grep '"version"' "${repo_root}/.claude-plugin/plugin.json" | grep -o '"[0-9.]*"' | tr -d '"')
  [[ "$version" == "3.12.0" ]] || {
    echo "FAIL: plugin.json の version が ${version} （期待: 3.12.0）"
    return 1
  }
}

# --- AT-007: Non-Goals 不可侵（CS-3） ---

@test "AT-007a: skills/reviewing-deliverables/SKILL.md has no diff from main" {
  # Given: git diff main の変更ファイル一覧
  # When: reviewing-deliverables/SKILL.md を検査する
  # Then: 差分がない
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  local diff_count
  diff_count=$(git -C "$repo_root" diff main -- skills/reviewing-deliverables/SKILL.md | wc -l | tr -d ' ')
  [[ "$diff_count" -eq 0 ]] || {
    echo "FAIL: skills/reviewing-deliverables/SKILL.md に差分がある（${diff_count} 行）"
    return 1
  }
}

@test "AT-007b: agents/README.md model policy blockquote is unchanged from main" {
  # Given: git diff main -- agents/README.md
  # When: blockquote 行の差分を検査する
  # Then: blockquote ブロック（> で始まる行）に削除・追加がない
  local repo_root
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  local blockquote_diff
  blockquote_diff=$(git -C "$repo_root" diff main -- agents/README.md | grep -E '^[+-]>' | grep -v '^---\|^+++' || true)
  [[ -z "$blockquote_diff" ]] || {
    echo "FAIL: agents/README.md の blockquote（#259 ポリシー）に差分がある:"
    echo "$blockquote_diff"
    return 1
  }
}
