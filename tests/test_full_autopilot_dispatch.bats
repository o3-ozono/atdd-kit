#!/usr/bin/env bats
# @covers: lib/full-autopilot-dispatch.sh
# =============================================================================
# full-autopilot-dispatch.sh -- dispatcher の slot/lease ゲート選択ロジック
# Issue #318 (b)。User Story F2（並列度 K）/ F3（数珠つなぎ）/ C2（並列排他）。
#
# キュー候補から「issue-lease を取得できた issue を最大 K 件」選ぶ。既に他
# セッションが claim 済みの issue はスキップする（lib/lease-store.sh を合成）。
#
#   FAD-1: 未 claim キューから先頭 K 件を選択
#   FAD-2: 他セッション claim 済み issue はスキップして次を埋める
#   FAD-3: キューが K 未満なら全件選択
#   FAD-4: 選択された issue は dispatcher 名義で lease される
# =============================================================================

LIB="lib/full-autopilot-dispatch.sh"
LEASE="lib/lease-store.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  LIB_PATH="$ROOT/$LIB"
  LEASE_PATH="$ROOT/$LEASE"
  STORE="$(mktemp -d)"
}

teardown() {
  rm -rf "$STORE"
}

fad() {
  LEASE_STORE_DIR="$STORE" FAD_SESSION=dispatcher GITHUB_ACTIONS= bash "$LIB_PATH" "$@"
}

claim_other() {
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$LEASE_PATH" acquire issue "$1" otherSession
}

@test "FAD-1: selects first K from an unclaimed queue" {
  run fad select 2 318 319 320
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "318" ]
  [ "${lines[1]}" = "319" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "FAD-2: skips issues already claimed by another session" {
  claim_other 318
  run fad select 2 318 319 320
  [ "${lines[0]}" = "319" ]
  [ "${lines[1]}" = "320" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "FAD-3: selects all when queue is shorter than K" {
  run fad select 3 318 319
  [ "${lines[0]}" = "318" ]
  [ "${lines[1]}" = "319" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "FAD-4: selected issues are leased to the dispatcher" {
  fad select 1 318
  run env LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$LEASE_PATH" holder issue 318
  [ "$output" = "dispatcher" ]
}
