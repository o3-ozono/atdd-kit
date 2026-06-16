#!/usr/bin/env bats
# @covers: lib/merge-coordinator.sh
# =============================================================================
# AT-318-C: merge coordinator — Story 受け入れ
# User Story F5（rebase→再ゲート→merge）/ F6（自動差し戻し）/ F7（エスカレーション）。
# 外部ステップはモック注入し、順序と失敗ハンドリングの振る舞いを検証する。
# =============================================================================

LIB="lib/merge-coordinator.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  LIB_PATH="$ROOT/$LIB"
  STATE="$(mktemp -d)"
  ORDER="$STATE/order.log"
}

teardown() {
  rm -rf "$STATE"
}

# AT-318-C1: rebase→再ゲート→merge の順序で統合する（broken-together 防止の構造）
@test "AT-318-C1: process runs rebase before regate before merge, then merges" {
  run env MC_STATE_DIR="$STATE" \
    MC_REBASE_CMD="$ROOT/tests/fixtures/mc-step.sh rebase $ORDER" \
    MC_REGATE_CMD="$ROOT/tests/fixtures/mc-step.sh regate $ORDER" \
    MC_MERGE_CMD="$ROOT/tests/fixtures/mc-step.sh merge $ORDER" \
    MC_REGRESSION_CMD="$ROOT/tests/fixtures/mc-step.sh regression $ORDER" \
    bash "$LIB_PATH" process 201 feat/x 3
  [ "$status" -eq 0 ]
  [ "$output" = "merged" ]
  # 順序: rebase が再ゲートより前、再ゲートが merge より前（= 再ゲートは merge 前に必ず走る）
  run cat "$ORDER"
  [ "${lines[0]}" = "rebase" ]
  [ "${lines[1]}" = "regate" ]
  [ "${lines[2]}" = "merge" ]
  [ "${lines[3]}" = "regression" ]
}

# AT-318-C2: rebase 失敗は自動差し戻し、N 回で human エスカレーション
@test "AT-318-C2: rebase failure retries then escalates at threshold N=3" {
  proc() {
    env MC_STATE_DIR="$STATE" \
      MC_REBASE_CMD="$ROOT/tests/fixtures/mc-step.sh rebase $ORDER fail" \
      bash "$LIB_PATH" process 202 feat/y 3
  }
  run proc; [ "$output" = "rebase-failed:retry" ]
  run proc; [ "$output" = "rebase-failed:retry" ]
  run proc; [ "$output" = "rebase-failed:escalate" ]
}
