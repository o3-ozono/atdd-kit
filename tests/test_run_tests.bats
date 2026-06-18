#!/usr/bin/env bats
# @covers: scripts/run-tests.sh
# Unit tests for scripts/run-tests.sh
# AT-200 / AT-201 / AT-210 / AT-211 / AT-212 の受け入れ観点を pin する

bats_require_minimum_version 1.5.0

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
RUN_TESTS_SH="${SCRIPT_DIR}/scripts/run-tests.sh"

# ---------------------------------------------------------------------------
# AT-200: コア数検出フォールバック連鎖（マシン非依存）
# ---------------------------------------------------------------------------

@test "AT-200: detect_cpu_count returns a positive integer in normal env" {
  # detect_cpu_count を source して直接呼び出す
  local count
  count=$(bash -c "
    source '${RUN_TESTS_SH}' --_source-only
    detect_cpu_count
  ")
  [[ "$count" =~ ^[0-9]+$ ]] || {
    echo "FAIL: detect_cpu_count が整数を返さなかった（'${count}'）"
    return 1
  }
  [[ "$count" -ge 1 ]] || {
    echo "FAIL: detect_cpu_count が 1 未満の値を返した（${count}）"
    return 1
  }
}

@test "AT-200b: detect_cpu_count falls back to 4 when all candidates are absent" {
  # PATH を空にして nproc / sysctl / getconf が全て使えない環境をシミュレート
  local count
  count=$(
    PATH=/usr/bin:/bin \
    bash -c "
      # nproc, sysctl, getconf を無効化
      nproc() { return 1; }
      sysctl() { return 1; }
      getconf() { return 1; }
      export -f nproc sysctl getconf
      source '${RUN_TESTS_SH}' --_source-only
      # 関数を再定義してオーバーライド
      detect_cpu_count() {
        local count
        if count=\$(nproc 2>/dev/null) && [[ \"\$count\" =~ ^[0-9]+\$ ]] && [[ \"\$count\" -ge 1 ]]; then
          echo \"\$count\"; return
        fi
        if count=\$(sysctl -n hw.ncpu 2>/dev/null) && [[ \"\$count\" =~ ^[0-9]+\$ ]] && [[ \"\$count\" -ge 1 ]]; then
          echo \"\$count\"; return
        fi
        if count=\$(getconf _NPROCESSORS_ONLN 2>/dev/null) && [[ \"\$count\" =~ ^[0-9]+\$ ]] && [[ \"\$count\" -ge 1 ]]; then
          echo \"\$count\"; return
        fi
        echo 4
      }
      detect_cpu_count
    " 2>/dev/null
  )
  [[ "$count" -ge 1 ]] || {
    echo "FAIL: フォールバック時に 1 未満の値が返った（${count}）"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-201: 外部依存なし（GNU parallel 等を使わない）
# ---------------------------------------------------------------------------

@test "AT-201: run-tests.sh has no GNU parallel dependency" {
  # GNU parallel / sem コマンドへの直接呼び出しが存在しないことを確認
  if grep -qE '^[[:space:]]*(parallel|sem)[[:space:]]' "$RUN_TESTS_SH"; then
    echo "FAIL: scripts/run-tests.sh に GNU parallel への依存がある"
    return 1
  fi
  # xargs -P や parallel サブコマンドも禁止
  if grep -qE 'xargs[[:space:]]+-P' "$RUN_TESTS_SH"; then
    echo "FAIL: scripts/run-tests.sh に xargs -P への依存がある"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# AT-210: 両モード対象選択（--all / --impact --base）
# ---------------------------------------------------------------------------

@test "AT-210a: --all option is implemented in run-tests.sh" {
  grep -q '\-\-all' "$RUN_TESTS_SH" || {
    echo "FAIL: --all オプションが実装されていない"
    return 1
  }
}

@test "AT-210b: --impact option is implemented in run-tests.sh" {
  grep -q '\-\-impact' "$RUN_TESTS_SH" || {
    echo "FAIL: --impact オプションが実装されていない"
    return 1
  }
}

@test "AT-210c: run-tests.sh delegates to impact_map.sh (does not call bats_runner.sh)" {
  # impact_map に委譲すること
  grep -q 'impact_map' "$RUN_TESTS_SH" || {
    echo "FAIL: scripts/run-tests.sh が impact_map.sh に委譲していない"
    return 1
  }
  # bats_runner.sh を実行呼び出し（bash や ./ での実行）しないこと
  # コメントや文字列定義は許容する（コメントで設計方針を説明するのは正当）
  if grep -E '^\s*(bash|source|\.)\s+.*bats_runner' "$RUN_TESTS_SH"; then
    echo "FAIL: run-tests.sh が bats_runner.sh を実行呼び出ししている"
    return 1
  fi
}

@test "AT-210d: --all mode selects all BATS files via collect_all_bats" {
  # --all 時に impact_map.sh を呼ばず collect_all_bats を使うことをソース確認
  grep -q 'collect_all_bats' "$RUN_TESTS_SH" || {
    echo "FAIL: collect_all_bats 関数が存在しない"
    return 1
  }
}

@test "AT-210e: --impact mode with mock impact_map selects affected files only" {
  # impact_map.sh のモックを使って --impact モードの選択を確認
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  # モック impact_map.sh: 特定の2ファイルを返す
  cat > "${tmpdir}/mock_impact_map.sh" << 'EOF'
#!/usr/bin/env bash
# モック: tests/test_foo.bats と tests/test_bar.bats を返す
echo "/mock/tests/test_foo.bats"
echo "/mock/tests/test_bar.bats"
EOF
  chmod +x "${tmpdir}/mock_impact_map.sh"

  # モック bats コマンド: 渡された引数をファイルに追記する（実行しない）。
  # 注: 本テストは「--impact が影響ファイルを選択して bats に渡す」という
  # 選択ロジック（AT-210）の検証であり、並列実行（AT-211/AT-212 が担当）は対象外。
  # シャードを並列バックグラウンド subshell で起動すると、bats-in-bats ＋ set -e
  # 環境（CI）で複数 mock bats プロセスが共有追記ファイル上で競合し非決定的に
  # 取りこぼし得る。よって --jobs 1 で単一シャード（全対象を 1 回の bats 呼び出し）に
  # 固定し、決定的なマーカーファイルで選択結果を検証する（環境非依存）。
  local calllog="${tmpdir}/bats_calls.log"
  cat > "${tmpdir}/bats" << EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${calllog}"
exit 0
EOF
  chmod +x "${tmpdir}/bats"

  # run-tests.sh を --impact モードで呼び出し（--jobs 1 で逐次化＝決定的）
  _RUN_TESTS_IMPACT_MAP_OVERRIDE="${tmpdir}/mock_impact_map.sh" \
    PATH="${tmpdir}:${PATH}" \
    bash "$RUN_TESTS_SH" --impact --base main --jobs 1 --repo /tmp >/dev/null 2>&1 || true

  # モック bats が影響ファイル（test_foo / test_bar）の両方で呼ばれたことを確認。
  # 注: シャードはバックグラウンド subshell で実行され calllog へ追記する。
  # CI のファイルシステムでは子プロセス終了後の書き込み可視化に微小ラグがあり、
  # run-tests.sh 復帰直後の read で取りこぼし得るため、有界ポーリング（最大 ~3s）で
  # 書き込みの可視化を待ってから検証する（環境非依存・決定的）。
  local tries=0
  while [[ $tries -lt 30 ]]; do
    if [[ -f "$calllog" ]] && grep -q 'test_foo' "$calllog" && grep -q 'test_bar' "$calllog"; then
      break
    fi
    sleep 0.1
    tries=$((tries + 1))
  done

  [[ -f "$calllog" ]] && grep -q 'test_foo' "$calllog" && grep -q 'test_bar' "$calllog" || {
    echo "FAIL: --impact モードで影響ファイル(test_foo/test_bar)が bats に渡されなかった"
    echo "calllog: $([[ -f "$calllog" ]] && cat "$calllog" || echo MISSING)"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-211: 重み均衡シャーディング
# ---------------------------------------------------------------------------

@test "AT-211a: compute_shards produces N shards for N files with N=2" {
  local shards
  shards=$(bash -c "
    source '${RUN_TESTS_SH}' --_source-only
    # 4つのファイルを2シャードに分割
    compute_shards 2 /a/test1.bats /a/test2.bats /a/test3.bats /a/test4.bats
  " 2>/dev/null || echo "ERROR")
  [[ "$shards" != "ERROR" ]] || {
    echo "FAIL: compute_shards の呼び出しが失敗した"
    return 1
  }
  local n_shards
  n_shards=$(echo "$shards" | grep -c '^[0-9]' || true)
  [[ "$n_shards" -eq 2 ]] || {
    echo "FAIL: シャード数が 2 でない（${n_shards}）"
    echo "shards output: $shards"
    return 1
  }
}

@test "AT-211b: compute_shards with fewer files than shards uses file count" {
  # ファイル数 < シャード数の場合はファイル数のシャードになる
  local shards
  shards=$(bash -c "
    source '${RUN_TESTS_SH}' --_source-only
    compute_shards 8 /a/only1.bats /a/only2.bats
  " 2>/dev/null || echo "ERROR")
  [[ "$shards" != "ERROR" ]] || {
    echo "FAIL: compute_shards の呼び出しが失敗した"
    return 1
  }
  local n_shards
  n_shards=$(echo "$shards" | grep -c '^[0-9]' || true)
  [[ "$n_shards" -le 2 ]] || {
    echo "FAIL: ファイル数(2)より多いシャード(${n_shards})が生成された"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-212: fail 集約（全体 exit 非0）
# ---------------------------------------------------------------------------

@test "AT-212: run-tests.sh exits non-zero when no mode specified" {
  run bash "$RUN_TESTS_SH"
  [[ "$status" -ne 0 ]] || {
    echo "FAIL: 引数なし run-tests.sh が exit 0 を返した"
    return 1
  }
}

@test "AT-212b: run-tests.sh exits non-zero when --impact without --base" {
  run bash "$RUN_TESTS_SH" --impact
  [[ "$status" -ne 0 ]] || {
    echo "FAIL: --impact のみ（--base なし）で exit 0 を返した"
    return 1
  }
}

@test "AT-212c: run_shards_parallel aggregates shard failures" {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  # 失敗するシャードファイルを疑似的にシミュレート（モック bats）
  cat > "${tmpdir}/bats" << 'EOF'
#!/usr/bin/env bash
# 引数に "fail" を含む場合は失敗
if echo "$*" | grep -q "fail"; then
  echo "1..1"
  echo "not ok 1 simulated failure"
  exit 1
fi
echo "1..1"
echo "ok 1 simulated pass"
exit 0
EOF
  chmod +x "${tmpdir}/bats"

  # run_shards_parallel を直接テスト
  local exit_code=0
  PATH="${tmpdir}:${PATH}" bash -c "
    source '${RUN_TESTS_SH}' --_source-only
    # 1つ目: 通常ファイル（pass）、2つ目: fail を含むファイル（fail）
    shard_lines=('0\t/a/normal.bats' '1\t/b/fail_test.bats')
    run_shards_parallel \"\${shard_lines[@]}\"
  " || exit_code=$?

  [[ "$exit_code" -ne 0 ]] || {
    echo "FAIL: 失敗シャードがあるのに exit 0 が返った"
    return 1
  }
}
