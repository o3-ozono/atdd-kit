#!/usr/bin/env bats
# @covers: lib/lease-store.sh
# =============================================================================
# AT-318-D: lease 拡張（issue-lease / merge-lease） — Story 受け入れ
# User Story C2（並列排他）。dispatcher / coordinator の視点で2セッションが
# 競合する振る舞いを検証する。
# =============================================================================

LIB="lib/lease-store.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  LIB_PATH="$ROOT/$LIB"
  STORE="$(mktemp -d)"
}

teardown() {
  rm -rf "$STORE"
}

lease() {
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$LIB_PATH" "$@"
}

# AT-318-D1: issue-lease が同一 issue の二重 claim を防ぐ
@test "AT-318-D1: issue-lease blocks double claim of the same issue" {
  # dispatcher セッション A が issue #318 を claim
  run lease acquire issue 318 dispatcherA
  [ "$status" -eq 0 ]
  # 並行 dispatcher B が同じ #318 を claim → ブロック
  run lease acquire issue 318 dispatcherB
  [ "$status" -ne 0 ]
  # 別 issue #319 は B が取れる（独立）
  run lease acquire issue 319 dispatcherB
  [ "$status" -eq 0 ]
}

# AT-318-D2: merge-lease 容量1が同時 merge を直列化
@test "AT-318-D2: merge-lease capacity 1 serializes concurrent merges" {
  # coordinator が main-merge を取得
  run lease acquire merge main-merge coordinator
  [ "$status" -eq 0 ]
  # 別主体の同時 merge 試行はブロック
  run lease acquire merge main-merge worker7
  [ "$status" -ne 0 ]
  # coordinator が解放すると次が取れる（直列に進む）
  run lease release merge main-merge coordinator
  [ "$status" -eq 0 ]
  run lease acquire merge main-merge worker7
  [ "$status" -eq 0 ]
}
