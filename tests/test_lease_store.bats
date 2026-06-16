#!/usr/bin/env bats
# @covers: lib/lease-store.sh
# =============================================================================
# lease-store.sh -- 汎用 lease ライブラリ（issue-lease / merge-lease）
# Issue #318 (d): #316 の branch-lease store 形式を踏襲した capacity-1/キーの
# クロスセッション lease。pool 名前空間で issue / merge を分離する。
#
# テスト対象の挙動:
#   LS-1: 空きキーの acquire は成功し holder が記録される
#   LS-2: 別セッションの fresh lease 保有キーへの acquire はブロック（holder 不変）
#   LS-3: 同一セッションの re-acquire は冪等（自己保有）
#   LS-4: merge pool は容量1で main-merge を直列化
#   LS-5: release で別セッションが再取得可能になる
#   LS-6: pool は分離（同一キー・異なる pool は独立）
#   LS-7: TTL 超過 lease はアクセス時に掃除され再取得可能
# =============================================================================

LIB="lib/lease-store.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  LIB_PATH="$ROOT/$LIB"
  STORE="$(mktemp -d)"
}

teardown() {
  rm -rf "$STORE"
}

# GITHUB_ACTIONS= で CI でも TTL_LOCAL 経路に固定（決定論的 TTL 制御）
run_lease() {
  LEASE_STORE_DIR="$STORE" LEASE_TTL_LOCAL="${TTL:-7200}" GITHUB_ACTIONS= bash "$LIB_PATH" "$@"
}

@test "LS-1: acquire on free key succeeds and records holder" {
  run run_lease acquire issue 318 sessA
  [ "$status" -eq 0 ]
  run run_lease holder issue 318
  [ "$output" = "sessA" ]
}

@test "LS-2: acquire on key held by other session is blocked, holder unchanged" {
  run_lease acquire issue 318 sessA
  run run_lease acquire issue 318 sessB
  [ "$status" -ne 0 ]
  run run_lease holder issue 318
  [ "$output" = "sessA" ]
}

@test "LS-3: re-acquire by same session is idempotent" {
  run_lease acquire issue 318 sessA
  run run_lease acquire issue 318 sessA
  [ "$status" -eq 0 ]
}

@test "LS-4: merge pool capacity 1 serializes main-merge" {
  run run_lease acquire merge main-merge sessA
  [ "$status" -eq 0 ]
  run run_lease acquire merge main-merge sessB
  [ "$status" -ne 0 ]
}

@test "LS-5: release frees key for another session" {
  run_lease acquire issue 318 sessA
  run run_lease release issue 318 sessA
  [ "$status" -eq 0 ]
  run run_lease acquire issue 318 sessB
  [ "$status" -eq 0 ]
}

@test "LS-6: pools are isolated for same key" {
  run_lease acquire issue main-merge sessA
  run run_lease acquire merge main-merge sessB
  [ "$status" -eq 0 ]
}

@test "LS-7: TTL-stale lease is cleaned at access and reacquirable" {
  run_lease acquire issue 318 sessA
  lf="$(run_lease path issue 318)"
  [ -f "$lf" ]
  # timestamp を 1970 に backdate（age 巨大 > TTL）
  python3 -c "import json; p='$lf'; d=json.load(open(p)); d['timestamp']=1; json.dump(d, open(p,'w'))"
  run env LEASE_STORE_DIR="$STORE" LEASE_TTL_LOCAL=10 GITHUB_ACTIONS= bash "$LIB_PATH" acquire issue 318 sessB
  [ "$status" -eq 0 ]
  run env LEASE_STORE_DIR="$STORE" LEASE_TTL_LOCAL=10 GITHUB_ACTIONS= bash "$LIB_PATH" holder issue 318
  [ "$output" = "sessB" ]
}
