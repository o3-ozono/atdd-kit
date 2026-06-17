#!/usr/bin/env bats
# @covers: lib/merge-coordinator.sh
# =============================================================================
# merge-coordinator.sh -- 失敗の自動差し戻し→閾値エスカレーション状態機械
# Issue #318 (c)。User Story F6（自動差し戻し）/ F7（エスカレーション）。
#
# 外部依存（rebase / 再ゲート / merge）は薄いラッパに分離し、本テストは
# 失敗カウント・閾値判定・成功リセットの分岐ロジックのみを対象とする。
#
#   MC-1: 初回失敗は retry（カウント 1 < N）
#   MC-2: 失敗が N 回未満の間は retry を返す
#   MC-3: 失敗回数が N 以上で escalate を返す
#   MC-4: 成功（clear）でカウントがリセットされ再び retry から始まる
#   MC-5: PR ごとにカウントは独立
# =============================================================================

LIB="lib/merge-coordinator.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  LIB_PATH="$ROOT/$LIB"
  STATE="$(mktemp -d)"
}

teardown() {
  rm -rf "$STATE"
}

mc() {
  MC_STATE_DIR="$STATE" bash "$LIB_PATH" "$@"
}

@test "MC-1: first failure decides retry when N=3" {
  run mc decide 101 3
  [ "$status" -eq 0 ]
  [ "$output" = "retry" ]
}

@test "MC-2: below threshold keeps deciding retry" {
  mc decide 101 3   # count 1
  run mc decide 101 3   # count 2
  [ "$output" = "retry" ]
}

@test "MC-3: reaching threshold decides escalate" {
  mc decide 101 3   # 1 retry
  mc decide 101 3   # 2 retry
  run mc decide 101 3   # 3 -> escalate
  [ "$output" = "escalate" ]
}

@test "MC-4: clear resets the counter" {
  mc decide 101 3
  mc decide 101 3
  mc clear 101
  run mc decide 101 3   # back to count 1
  [ "$output" = "retry" ]
}

@test "MC-6: post-merge regression failure is surfaced (non-zero), not swallowed" {
  ORDER="$STATE/order.log"
  run env MC_STATE_DIR="$STATE" \
    MC_REBASE_CMD="true" MC_REGATE_CMD="true" MC_MERGE_CMD="true" \
    MC_REGRESSION_CMD="false" \
    bash "$LIB_PATH" process 303 feat/z 3
  [ "$status" -ne 0 ]
  [ "$output" = "merged:regression-failed" ]
}

@test "MC-5: failure counts are per-PR independent" {
  mc decide 101 2   # PR101 count1
  mc decide 101 2   # PR101 count2 -> escalate next; but check PR102 fresh
  run mc decide 102 2
  [ "$output" = "retry" ]
}
