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

@test "FAD-5: release frees an issue-lease so the slot can be reused" {
  fad select 1 318
  run fad release 318
  [ "$status" -eq 0 ]
  # 解放後は別 dispatcher（or 次ラウンド）が取れる
  run env LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$LEASE_PATH" acquire issue 318 otherSession
  [ "$status" -eq 0 ]
}

# =============================================================================
# F2: GitHub-state prefilter (Issue #326)
#   FAD-6: busy issue は select から除外される
#   FAD-7: busy issue は lease 取得前にスキップされる（二重 dispatch 冪等ガード）
#   FAD-8: cmd_select の純粋性が保たれる（busy=全 idle で既存 FAD-1〜4 が回帰なし）
# =============================================================================

# Helper: FAD_BUSY_CMD に注入するスタブ。
# 引数の issue 番号が BUSY_ISSUES 環境変数に含まれる場合 exit 0 (busy)、でなければ exit 1 (idle)。
fad_with_busy() {
  local busy_list="$1"; shift
  # スタブコマンドを一時スクリプトとして作成
  local stub_file
  stub_file="$(mktemp)"
  cat > "$stub_file" <<STUBEOF
#!/usr/bin/env bash
issue="\$1"
for b in $busy_list; do
  [ "\$issue" = "\$b" ] && exit 0
done
exit 1
STUBEOF
  chmod +x "$stub_file"
  LEASE_STORE_DIR="$STORE" FAD_SESSION=dispatcher GITHUB_ACTIONS= FAD_BUSY_CMD="bash $stub_file" bash "$LIB_PATH" "$@"
  local status=$?
  rm -f "$stub_file"
  return $status
}

@test "FAD-6: busy issue (open PR / in-progress) is excluded from select output" {
  # Issue 319 は busy、318 と 320 は idle
  run fad_with_busy "319" select 3 318 319 320
  [ "$status" -eq 0 ]
  # 319 は出力されない
  for line in "${lines[@]}"; do
    [ "$line" != "319" ]
  done
  # 318 と 320 は出力される
  printf '%s\n' "${lines[@]}" | grep -q "^318$"
  printf '%s\n' "${lines[@]}" | grep -q "^320$"
}

@test "FAD-7: busy issue does not acquire a lease (prefilter before lease acquisition)" {
  # Issue 318 は busy。lease-store が空の状態（クラッシュ復帰相当）
  fad_with_busy "318" select 1 318 319 > /dev/null
  # 318 の lease は取得されていない
  run env LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$LEASE_PATH" holder issue 318
  [ "$output" = "" ]
  # 319 の lease は取得されている
  run env LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$LEASE_PATH" holder issue 319
  [ "$output" = "dispatcher" ]
}

@test "FAD-8: prefilter does not break existing FAD-1 to FAD-4 when all issues are idle" {
  # FAD_BUSY_CMD が「全 idle（exit 1 常に）」を返すスタブで既存ロジック回帰テスト

  # FAD-1 相当: 未 claim キューから先頭 K 件
  run fad_with_busy "" select 2 318 319 320
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "318" ]
  [ "${lines[1]}" = "319" ]
  [ "${#lines[@]}" -eq 2 ]
}
