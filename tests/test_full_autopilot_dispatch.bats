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

# =============================================================================
# FAD-9: デフォルト is_issue_busy の gh pr list 構文が正しく open PR を検出する
# （FAD_BUSY_CMD 未設定＝デフォルト実装パス）
#
# レビューフィンディング #326: `gh pr list --jq --arg n "$issue"` は gh CLI では
# 無効な構文（--arg は jq にのみ有効）。open PR 判定が常に false になり C2 違反。
# 修正後の構文（シェル変数直接展開）が正しく動作することを検証する。
# =============================================================================

# Helper: FAD_BUSY_CMD を未設定にしてモック gh を FAKE_BIN に置いた状態で fad を実行
# モック gh は "pr list" で issue 番号に一致するブランチ (318-foo) を返す
fad_default_impl() {
  local fake_bin
  fake_bin="$(mktemp -d)"

  # モック gh: `gh pr list --state open --json ...` に対して
  # issue 318 に一致するブランチ 318-foo を持つ PR JSON を返す。
  # --jq フィルタは実際の jq で処理する（gh CLI の内部 jq 処理を模倣）。
  cat > "$fake_bin/gh" <<'GHEOF'
#!/usr/bin/env bash
PR_DATA='[{"number":99,"headRefName":"318-foo"}]'

if [[ "$*" == *"pr list"* ]] && [[ "$*" == *"--json"* ]]; then
  # --jq フィルタを取り出して実際に jq で処理する
  jq_filter=""
  args=("$@")
  for i in "${!args[@]}"; do
    if [[ "${args[$i]}" == "--jq" ]]; then
      jq_filter="${args[$((i+1))]}"
      break
    fi
  done
  if [ -n "$jq_filter" ]; then
    printf '%s' "$PR_DATA" | jq "$jq_filter"
  else
    printf '%s\n' "$PR_DATA"
  fi
  exit 0
fi

if [[ "$*" == *"issue view"* ]] && [[ "$*" == *"--json"* ]]; then
  # in-progress ラベルなし → 0 を返す
  jq_filter=""
  args=("$@")
  for i in "${!args[@]}"; do
    if [[ "${args[$i]}" == "--jq" ]]; then
      jq_filter="${args[$((i+1))]}"
      break
    fi
  done
  ISSUE_DATA='{"labels":[]}'
  if [ -n "$jq_filter" ]; then
    printf '%s' "$ISSUE_DATA" | jq "$jq_filter"
  else
    printf '%s\n' "$ISSUE_DATA"
  fi
  exit 0
fi

echo "[]"
exit 0
GHEOF
  chmod +x "$fake_bin/gh"

  LEASE_STORE_DIR="$STORE" FAD_SESSION=dispatcher GITHUB_ACTIONS= \
    PATH="$fake_bin:$PATH" \
    bash "$LIB_PATH" "$@"
  local ret=$?
  rm -rf "$fake_bin"
  return $ret
}

@test "FAD-9: default is_issue_busy detects open PR via correct gh pr list syntax" {
  # モック gh が issue 318 のブランチ (318-foo) を持つ open PR を返す状態
  # FAD_BUSY_CMD 未設定 → デフォルト実装の gh pr list 構文が正しく動作するはず
  # 修正前: --jq --arg n "$issue" は gh では無効で常に open_prs=0 → 318 が選ばれてしまう
  # 修正後: シェル変数展開でブランチプレフィックス判定 → 318 は除外される
  run fad_default_impl select 2 318 319 320
  [ "$status" -eq 0 ]
  # 318 は open PR あり → busy → 出力されないはず
  for line in "${lines[@]}"; do
    [ "$line" != "318" ]
  done
  # 319 と 320 は idle → 出力される
  printf '%s\n' "${lines[@]}" | grep -q "^319$"
  printf '%s\n' "${lines[@]}" | grep -q "^320$"
}
