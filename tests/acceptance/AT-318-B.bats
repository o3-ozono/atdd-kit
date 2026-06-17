#!/usr/bin/env bats
# @covers: lib/full-autopilot-run.sh
# =============================================================================
# AT-318-B / E1: dispatcher ランタイム（数珠つなぎ本体）— Story 受け入れ
# User Story F2（並列度 K）/ F3（数珠つなぎ）/ C2（並列排他）/ E1（無人フルループ）。
# worker / result / merge は注入モックで置換し、ランタイムの並列度・スロット連鎖・
# merge handoff・lease 解放を決定論的に検証する（実 claude -p は別途 live smoke）。
# =============================================================================

RUN="lib/full-autopilot-run.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  RUN_PATH="$ROOT/$RUN"
  STORE="$(mktemp -d)"
  CC="$(mktemp -d)"; mkdir -p "$CC/active"
  : > "$CC/samples"; : > "$CC/launched"; : > "$CC/merged"
  Q="$STORE/queue"
}

teardown() { rm -rf "$STORE" "$CC"; }

fa_run() {
  local k="$1"
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= FA_SESSION=fa CC_DIR="$CC" MOCK_SLEEP=0.3 \
    FA_FAIL_ISSUES="${FA_FAIL_ISSUES:-}" \
    FA_LOG="$CC/log" FA_RUNDIR="$CC/run" FA_POLL_INTERVAL=0.05 \
    FA_QUEUE_CMD="cat $Q" \
    FA_LAUNCH_CMD="bash $ROOT/tests/fixtures/fa-mock-worker.sh" \
    FA_RESULT_CMD="bash $ROOT/tests/fixtures/fa-mock-result.sh" \
    FA_MERGE_CMD="bash $ROOT/tests/fixtures/fa-mock-merge.sh" \
    bash "$RUN_PATH" "$k"
}

max_concurrency() { sort -n "$CC/samples" | tail -1; }

# AT-318-B2: 並列度 K=2 で2 issue 同時進行（max concurrency が 2 に達する）
@test "AT-318-B2: K=2 runs two issues concurrently (max concurrency reaches 2)" {
  printf '318\n319\n' > "$Q"
  fa_run 2
  [ "$(grep -c . "$CC/launched")" -eq 2 ]
  [ "$(max_concurrency)" -eq 2 ]
  [ "$(grep -c . "$CC/merged")" -eq 2 ]
}

# AT-318-B3: K=2・3 issue を再起動なしに全消化（数珠つなぎ）かつ K を超えない
@test "AT-318-B3: K=2 drains 3 issues by chaining without exceeding the cap" {
  printf '318\n319\n320\n' > "$Q"
  fa_run 2
  [ "$(grep -c . "$CC/launched")" -eq 3 ]
  [ "$(max_concurrency)" -le 2 ]
  [ "$(grep -c . "$CC/merged")" -eq 3 ]
}

# AT-318-B/E: worker 完了後に issue-lease が解放される（スロットが空く）
@test "AT-318-B: issue-lease is released after each worker completes" {
  printf '318\n319\n' > "$Q"
  fa_run 2
  run env LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$ROOT/lib/lease-store.sh" holder issue 318
  [ -z "$output" ]
  run env LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$ROOT/lib/lease-store.sh" holder issue 319
  [ -z "$output" ]
}

# AT-318-E1: 壁打ち以外無人で全 issue が merge まで到達（フル無人ループ・mock worker）
@test "AT-318-E1: full unattended loop merges every queued issue (mock workers)" {
  printf '318\n319\n320\n' > "$Q"
  fa_run 2
  for i in 318 319 320; do
    grep -qx "$i" "$CC/merged"
  done
  grep -q 'drain-complete' "$CC/log"
}

# 失敗 worker は merge されないが lease は解放される（数珠つなぎを止めない）
@test "AT-318-B: failed worker is not merged but its lease is released" {
  printf '318\n319\n' > "$Q"
  FA_FAIL_ISSUES="319" fa_run 2
  grep -qx '318' "$CC/merged"
  ! grep -qx '319' "$CC/merged"
  run env LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$ROOT/lib/lease-store.sh" holder issue 319
  [ -z "$output" ]
}
