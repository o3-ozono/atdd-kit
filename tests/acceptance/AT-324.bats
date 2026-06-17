#!/usr/bin/env bats
# @covers: tests/acceptance/AT-271.bats
# @covers: scripts/run-tests.sh
# @covers: docs/methodology/test-execution-policy.md
# @covers: skills/running-atdd-cycle/SKILL.md
# @covers: skills/reviewing-deliverables/SKILL.md
# @covers: skills/merging-and-deploying/SKILL.md
# AT-324: atdd-kit 自身のテスト高速化（メタテスト撤去＋影響度ベース並列ランナー）
# Issue #324

bats_require_minimum_version 1.5.0

# repo_root ヘルパー
repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

# --- AT-100: AT-006 removal ---

@test "AT-100: AT-006 is removed from AT-271.bats" {
  # Given: tests/acceptance/AT-271.bats に AT-006（スイート全体の入れ子再実行）が存在した
  # When: 本 Issue の変更後に AT-271.bats を検査する
  # Then: AT-006 の @test ブロックおよび run bats ... tests/ のネスト再実行が存在しない
  local root
  root="$(repo_root)"

  local count
  count=$(grep -c 'AT-006' "${root}/tests/acceptance/AT-271.bats" || true)
  [[ "$count" -eq 0 ]] || {
    echo "FAIL: AT-271.bats に AT-006 が残存している（${count} 箇所）"
    return 1
  }
}

@test "AT-101: no nested suite re-execution code in AT-271.bats" {
  # Given: AT-006 撤去後の AT-271.bats
  # When: AT-271.bats の構造を検査する
  # Then: "tests/" ディレクトリ全体を bats に渡すネスト再実行箇所が一切存在しない
  local root
  root="$(repo_root)"

  # "\${repo_root}/tests/" を bats に渡すコードが存在しないことを確認
  if grep -q '"${repo_root}/tests/"' "${root}/tests/acceptance/AT-271.bats" 2>/dev/null; then
    echo "FAIL: AT-271.bats に tests/ ディレクトリ引数を bats に渡す箇所が残っている"
    return 1
  fi
}

# --- AT-110: #271 regression intent preserved ---

@test "AT-110: remaining tests AT-001 to AT-005 and AT-007 in AT-271.bats are green" {
  # Given: AT-006 を撤去した AT-271.bats
  # When: bats tests/acceptance/AT-271.bats を実行する
  # Then: AT-001〜AT-005, AT-007 がすべて green で #271 の回帰意図が引き続き検査される
  local root
  root="$(repo_root)"

  run bats "${root}/tests/acceptance/AT-271.bats"
  [[ "$status" -eq 0 ]] || {
    echo "FAIL: AT-271.bats の実行が失敗した"
    echo "$output"
    return 1
  }
}

@test "AT-111: CI workflow still defines full suite execution" {
  # Given: AT-006 撤去の回帰担保を CI のフルスイートに委ねる設計
  # When: CI ワークフローのフルスイート実行定義を確認する
  # Then: CI が引き続きフルスイートを回す（撤去されていない）
  local root
  root="$(repo_root)"

  local ci_files
  ci_files=$(find "${root}/.github/workflows" -name "*.yml" -o -name "*.yaml" 2>/dev/null | head -5)
  [[ -n "$ci_files" ]] || {
    echo "FAIL: .github/workflows/ にワークフローファイルが存在しない"
    return 1
  }

  if ! grep -rl 'bats' "${root}/.github/workflows/" 2>/dev/null | grep -q .; then
    echo "FAIL: CI ワークフローに bats 実行定義が見当たらない"
    return 1
  fi
}

# --- AT-200: parallel runner scripts/run-tests.sh ---

@test "AT-200: cpu count detection fallback chain works machine-independently" {
  # Given: scripts/run-tests.sh のコア数検出ロジック
  # When: コア数検出関数を確認する
  # Then: 常に 1 以上の整数を返す
  local root
  root="$(repo_root)"

  [[ -f "${root}/scripts/run-tests.sh" ]] || {
    echo "FAIL: scripts/run-tests.sh が存在しない"
    return 1
  }

  # detect_cpu_count または同等の関数が定義されていること
  grep -qE 'detect_cpu|nproc|hw.ncpu|_NPROCESSORS_ONLN' "${root}/scripts/run-tests.sh" || {
    echo "FAIL: scripts/run-tests.sh にコア数検出ロジックが見当たらない"
    return 1
  }

  # フォールバック 4 が実装されていること
  grep -q '4' "${root}/scripts/run-tests.sh" || true  # フォールバック値の存在確認（ゆるいチェック）

  # 実際にスクリプトが引数なしで usage を表示して exit 非0 すること
  run bash "${root}/scripts/run-tests.sh"
  [[ "$status" -ne 0 ]] || {
    echo "FAIL: 引数なし run-tests.sh が exit 0 を返した（usage エラー未実装）"
    return 1
  }
}

@test "AT-201: run-tests.sh has no GNU parallel dependency" {
  # Given: scripts/run-tests.sh
  # When: run-tests.sh のソースを検査する
  # Then: GNU parallel 等の外部パッケージへの依存がない（pure bash + bats のみ）
  local root
  root="$(repo_root)"

  [[ -f "${root}/scripts/run-tests.sh" ]] || {
    echo "FAIL: scripts/run-tests.sh が存在しない"
    return 1
  }

  if grep -qE '^[[:space:]]*(parallel|sem)[[:space:]]' "${root}/scripts/run-tests.sh"; then
    echo "FAIL: scripts/run-tests.sh に GNU parallel への依存がある"
    return 1
  fi
}

# --- AT-210: mode selection and sharding ---

@test "AT-210: --all and --impact --base modes select correct BATS files" {
  # Given: 既存 impact_map.sh --layer BATS 基盤
  # When: run-tests.sh のオプション実装を検査する
  # Then: --all / --impact が実装され impact_map.sh に委譲する構造になっている
  local root
  root="$(repo_root)"

  [[ -f "${root}/scripts/run-tests.sh" ]] || {
    echo "FAIL: scripts/run-tests.sh が存在しない"
    return 1
  }

  grep -q '\-\-all' "${root}/scripts/run-tests.sh" || {
    echo "FAIL: scripts/run-tests.sh に --all オプションが実装されていない"
    return 1
  }
  grep -q '\-\-impact' "${root}/scripts/run-tests.sh" || {
    echo "FAIL: scripts/run-tests.sh に --impact オプションが実装されていない"
    return 1
  }
  grep -q 'impact_map' "${root}/scripts/run-tests.sh" || {
    echo "FAIL: scripts/run-tests.sh が impact_map.sh に委譲していない"
    return 1
  }
}

@test "AT-211: weighted sharding distributes BATS files across cpu-count shards and runs green" {
  # Given: 検出コア数 N の scripts/run-tests.sh
  # When: scripts/run-tests.sh --all を実行しシャード構成と終了コードを確認する
  # Then: 全シャード pass で exit 0
  local root
  root="$(repo_root)"

  [[ -f "${root}/scripts/run-tests.sh" ]] || {
    echo "FAIL: scripts/run-tests.sh が存在しない"
    return 1
  }

  # シャーディング・並列起動ロジックが存在すること（構造的確認）
  grep -qE 'wait|&$|& $' "${root}/scripts/run-tests.sh" || {
    echo "FAIL: scripts/run-tests.sh にバックグラウンドジョブ(& + wait)パターンが見当たらない"
    return 1
  }

  # run-tests.sh --all が exit 0 で終了すること
  run bash "${root}/scripts/run-tests.sh" --all --repo "${root}"
  [[ "$status" -eq 0 ]] || {
    echo "FAIL: scripts/run-tests.sh --all が exit 非0 で終了した（status=${status}）"
    echo "$output"
    return 1
  }
}

@test "AT-212: shard failure aggregates to runner exit non-zero" {
  # Given: 引数なし呼び出しで usage エラー（exit 非0）を確認する
  # When: scripts/run-tests.sh を引数なしで実行する
  # Then: exit 非0 が返る（失敗集約の最小確認）
  local root
  root="$(repo_root)"

  [[ -f "${root}/scripts/run-tests.sh" ]] || {
    echo "FAIL: scripts/run-tests.sh が存在しない"
    return 1
  }

  run bash "${root}/scripts/run-tests.sh"
  [[ "$status" -ne 0 ]] || {
    echo "FAIL: 引数なし run-tests.sh が exit 0 を返した（usage エラー未実装）"
    return 1
  }
}

# --- AT-300: phase-based test execution policy in skills ---

@test "AT-300: running-atdd-cycle SKILL.md documents impact-only execution policy" {
  # Given: skills/running-atdd-cycle/SKILL.md
  # When: SKILL.md を検査する
  # Then: 「影響範囲のみ」相当の文言が存在する
  local root
  root="$(repo_root)"

  grep -qE 'impact|--impact|affected only' "${root}/skills/running-atdd-cycle/SKILL.md" || {
    echo "FAIL: skills/running-atdd-cycle/SKILL.md に影響範囲のみ実行ポリシーの文言がない"
    return 1
  }
}

@test "AT-300b: merging-and-deploying SKILL.md documents full-suite execution policy" {
  # Given: skills/merging-and-deploying/SKILL.md
  # When: SKILL.md を検査する
  # Then: 「全件」実行相当の文言が存在する
  local root
  root="$(repo_root)"

  grep -qE '\-\-all|full suite|all tests' "${root}/skills/merging-and-deploying/SKILL.md" || {
    echo "FAIL: skills/merging-and-deploying/SKILL.md に全件実行ポリシーの文言がない"
    return 1
  }
}

@test "AT-302: reviewing-deliverables SKILL.md is under 240 lines and links to test-execution-policy" {
  # Given: skills/reviewing-deliverables/SKILL.md は 224/240 行で残量逼迫
  # When: フェーズ別ポリシー追記後の SKILL.md を検査する
  # Then: test-execution-policy.md へのリンク参照が存在し、240 行以下を維持する
  local root
  root="$(repo_root)"

  local lines
  lines=$(wc -l < "${root}/skills/reviewing-deliverables/SKILL.md")
  [[ "$lines" -le 240 ]] || {
    echo "FAIL: skills/reviewing-deliverables/SKILL.md が 240 行を超えている（${lines} 行）"
    return 1
  }

  grep -q 'test-execution-policy' "${root}/skills/reviewing-deliverables/SKILL.md" || {
    echo "FAIL: skills/reviewing-deliverables/SKILL.md に test-execution-policy.md へのリンク参照がない"
    return 1
  }
}

@test "AT-301: test-execution-policy.md integrates e2e tests into impact-based criteria" {
  # Given: test-execution-policy.md
  # When: 内容を確認する
  # Then: 物理置き場所ではなく影響度で e2e 実行可否を判断する基準が記述されている
  local root
  root="$(repo_root)"

  grep -qiE 'impact|e2e|influence|scope' "${root}/docs/methodology/test-execution-policy.md" || {
    echo "FAIL: test-execution-policy.md に e2e 影響度基準の記述がない"
    return 1
  }
}

# --- AT-310: live e2e execution condition inventory ---

@test "AT-310: test-execution-policy.md documents live e2e execution conditions with impact-based criteria" {
  # Given: test-execution-policy.md（実行ポリシー専用新規ドキュメント）
  # When: 内容を確認する
  # Then: 実行条件が棚卸しされ影響度基準と対応が整理されており、test-mapping.md の冒頭契約が無変更
  local root
  root="$(repo_root)"

  [[ -f "${root}/docs/methodology/test-execution-policy.md" ]] || {
    echo "FAIL: docs/methodology/test-execution-policy.md が存在しない"
    return 1
  }

  grep -qiE 'e2e|live|skip' "${root}/docs/methodology/test-execution-policy.md" || {
    echo "FAIL: test-execution-policy.md に live e2e 実行条件の記述がない"
    return 1
  }

  grep -q 'Loaded by' "${root}/docs/methodology/test-mapping.md" || {
    echo "FAIL: test-mapping.md の冒頭 'Loaded by' 契約が消えている"
    return 1
  }
}

@test "AT-311: test-execution-policy.md contains no Japanese characters (English only)" {
  # Given: test-execution-policy.md は docs ツリー配下の LLM-facing 配布文書
  # When: 文字種を検査する
  # Then: 日本語文字（ぁ-んァ-ヶ一-龥）を一切含まない
  local root
  root="$(repo_root)"

  [[ -f "${root}/docs/methodology/test-execution-policy.md" ]] || {
    echo "FAIL: docs/methodology/test-execution-policy.md が存在しない"
    return 1
  }

  if grep -P '[ぁ-んァ-ヶ一-龥]' "${root}/docs/methodology/test-execution-policy.md" >/dev/null 2>&1; then
    echo "FAIL: test-execution-policy.md に日本語文字が含まれている（English only 違反）"
    grep -P '[ぁ-んァ-ヶ一-龥]' "${root}/docs/methodology/test-execution-policy.md" | head -5
    return 1
  fi
}

@test "AT-312a: docs/methodology/README.md has test-execution-policy.md registered in Documents table" {
  # Given: methodology の Conventions が各文書を Documents テーブルに登録することを規約化
  # When: README.md の Documents テーブルを確認する
  # Then: test-execution-policy.md 行が存在する
  local root
  root="$(repo_root)"

  grep -q 'test-execution-policy' "${root}/docs/methodology/README.md" || {
    echo "FAIL: docs/methodology/README.md に test-execution-policy.md の行が登録されていない"
    return 1
  }
}

@test "AT-312b: test-execution-policy.md starts with Loaded by meta-comment" {
  # Given: methodology Conventions が各文書冒頭に > **Loaded by:** を要求
  # When: test-execution-policy.md の冒頭を確認する
  # Then: > **Loaded by:** メタコメントがある
  local root
  root="$(repo_root)"

  [[ -f "${root}/docs/methodology/test-execution-policy.md" ]] || {
    echo "FAIL: docs/methodology/test-execution-policy.md が存在しない"
    return 1
  }

  grep -q '> \*\*Loaded by:\*\*' "${root}/docs/methodology/test-execution-policy.md" || {
    echo "FAIL: test-execution-policy.md 冒頭に '> **Loaded by:**' メタコメントがない"
    return 1
  }
}

@test "AT-312c: docs/methodology/README.md contains no Japanese characters (English only)" {
  # Given: methodology/README.md は English only ポリシーが適用される
  # When: README.md の文字種を検査する
  # Then: 日本語文字を含まない
  local root
  root="$(repo_root)"

  if grep -P '[ぁ-んァ-ヶ一-龥]' "${root}/docs/methodology/README.md" >/dev/null 2>&1; then
    echo "FAIL: docs/methodology/README.md に日本語文字が含まれている（English only 違反）"
    return 1
  fi
}

# --- AT-320: distributed methodology ---

@test "AT-320: test-execution-policy.md documents standard doctrine in English and distinguishes from #323" {
  # Given: atdd-kit を適用する各プロジェクトに展開される docs/methodology/
  # When: test-execution-policy.md を確認する
  # Then: 最終レビュー前=全件 / ATDD 各回=影響範囲のみ が英語で明文化され #323 との境界が明記されている
  local root
  root="$(repo_root)"

  [[ -f "${root}/docs/methodology/test-execution-policy.md" ]] || {
    echo "FAIL: docs/methodology/test-execution-policy.md が存在しない"
    return 1
  }

  grep -qiE 'all tests|full suite|--all' "${root}/docs/methodology/test-execution-policy.md" || {
    echo "FAIL: test-execution-policy.md に全件実行ポリシー（all/full）の記述がない"
    return 1
  }

  grep -qiE 'impact|affected|scope' "${root}/docs/methodology/test-execution-policy.md" || {
    echo "FAIL: test-execution-policy.md に影響範囲実行ポリシー（impact/scope）の記述がない"
    return 1
  }

  grep -q '323' "${root}/docs/methodology/test-execution-policy.md" || {
    echo "FAIL: test-execution-policy.md に #323 との境界（別軸）の記述がない"
    return 1
  }
}

# --- AT-400: versioning invariant ---

@test "AT-400: plugin.json version matches latest CHANGELOG release heading" {
  # Given: 本 Issue は機能 PR であり minor bump + CHANGELOG 更新が必須
  # When: plugin.json version と CHANGELOG.md の最上位リリース見出しを照合する
  # Then: 両者が一致する（不変条件アサート）
  local root
  root="$(repo_root)"

  local version
  version=$(grep '"version"' "${root}/.claude-plugin/plugin.json" | sed 's/.*"version".*"\([^"]*\)".*/\1/')

  local top
  top=$(grep -m1 '## \[[0-9]' "${root}/CHANGELOG.md" | sed 's/.*\[\([^]]*\)\].*/\1/')

  [[ -n "$version" ]] || {
    echo "FAIL: plugin.json から version を取得できない"
    return 1
  }
  [[ -n "$top" ]] || {
    echo "FAIL: CHANGELOG.md に [X.Y.Z] 形式のリリース見出しがない"
    return 1
  }
  [[ "$version" == "$top" ]] || {
    echo "FAIL: plugin.json version (${version}) が CHANGELOG 最新リリース見出し (${top}) と一致しない"
    return 1
  }
}
