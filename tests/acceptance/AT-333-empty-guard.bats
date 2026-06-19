#!/usr/bin/env bats
# @covers: lib/full-autopilot-run.sh
# =============================================================================
# AT-333-empty-guard: __default_result が「空成果」を merge-ready と誤判定しない
#
# #333 の再現: headless worker が /atdd-kit:autopilot を解決できず
#   {"is_error":false,"num_turns":0,"result":"Unknown command: /atdd-kit:autopilot"}
# を返したのに、__default_result が is_error:false の自己申告（＋ stale な
# merge-ready ラベル）だけで merge-ready と誤判定し、空成果が merge coordinator
# に渡る（#329 H6 と同根の「成否判定の自己申告依存」）。
#
# 直接証拠（num_turns:0 / result の "Unknown command"）をラベル照合の前に
# fail-closed で検知することを pin する。AT-329-result の happy-path は壊さない。
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  RUN_PATH="$ROOT/lib/full-autopilot-run.sh"
  STORE="$(mktemp -d)"
  RUNDIR="$(mktemp -d)"
  ISSUE="333"
}

teardown() { rm -rf "$STORE" "$RUNDIR"; }

# Helper: __default_result を gh スタブ下で呼ぶ（AT-329-result と同方式）。
# $2 = gh が返すラベル（改行区切り）。out.json は各テストが事前に書く。
call_default_result() {
  local issue="$1" gh_labels="$2"
  local bin="$STORE/stubbin"; mkdir -p "$bin"
  cat > "$bin/gh" <<STUBEOF
#!/usr/bin/env bash
echo "$gh_labels"
STUBEOF
  chmod +x "$bin/gh"
  PATH="$bin:$PATH" FA_RUNDIR="$RUNDIR" \
    bash -c ". '$RUN_PATH' 2>/dev/null; __default_result '$issue'" 2>/dev/null
}

# 再現 1: #333 の実走 stdout そのもの（Unknown command + num_turns:0）。
# merge-ready ラベルが（stale で）付いていても failed に倒れること。
@test "AT-333-a: Unknown command result is failed even with merge-ready label" {
  printf '{"is_error":false,"num_turns":0,"result":"Unknown command: /atdd-kit:autopilot","total_cost_usd":0}\n' \
    > "$RUNDIR/$ISSUE.out.json"
  result=$(call_default_result "$ISSUE" "merge-ready")
  [ "$result" = "failed" ]
}

# 再現 2: num_turns:0 の空成果（worker が実装に未到達）は failed。
@test "AT-333-b: num_turns:0 empty result is failed even with merge-ready label" {
  printf '{"is_error":false,"num_turns":0,"result":"ok"}\n' > "$RUNDIR/$ISSUE.out.json"
  result=$(call_default_result "$ISSUE" "merge-ready")
  [ "$result" = "failed" ]
}

# 再現 3: result に "Unknown command" を含めば num_turns に依らず failed。
@test "AT-333-c: result containing Unknown command is failed regardless of num_turns" {
  printf '{"is_error":false,"num_turns":3,"result":"Unknown command: /atdd-kit:foo"}\n' > "$RUNDIR/$ISSUE.out.json"
  result=$(call_default_result "$ISSUE" "merge-ready")
  [ "$result" = "failed" ]
}

# 回帰防止: 実成果（num_turns>0・Unknown command なし）＋ merge-ready ラベルは
# 従来どおり merge-ready（happy-path を壊さない、AT-329-3b と整合）。
@test "AT-333-d: real result with positive num_turns and merge-ready label stays merge-ready" {
  printf '{"is_error":false,"num_turns":12,"result":"hand-off complete"}\n' > "$RUNDIR/$ISSUE.out.json"
  result=$(call_default_result "$ISSUE" "merge-ready")
  [ "$result" = "merge-ready" ]
}

# 回帰防止: num_turns:20 を num_turns:0 と誤検知しない（部分一致ガード）。
@test "AT-333-e: num_turns:20 is not misdetected as zero-turn" {
  printf '{"is_error":false,"num_turns":20,"result":"done"}\n' > "$RUNDIR/$ISSUE.out.json"
  result=$(call_default_result "$ISSUE" "merge-ready")
  [ "$result" = "merge-ready" ]
}

# fail-closed: out.json が存在しない（worker が出力前に kill / cd 失敗で exit 1）
# 場合は merge-ready ラベルがあっても failed（lib:89 で文書化された安全特性のピン留め）。
@test "AT-333-f: missing out.json is failed even with merge-ready label" {
  rm -f "$RUNDIR/$ISSUE.out.json"
  result=$(call_default_result "$ISSUE" "merge-ready")
  [ "$result" = "failed" ]
}

# 整形済み JSON（コロン後スペース）の num_turns:0 も空成果として failed に倒す。
@test "AT-333-g: pretty-printed num_turns: 0 is detected as zero-turn" {
  printf '{\n  "is_error": false,\n  "num_turns": 0,\n  "result": "ok"\n}\n' > "$RUNDIR/$ISSUE.out.json"
  result=$(call_default_result "$ISSUE" "merge-ready")
  [ "$result" = "failed" ]
}
