#!/usr/bin/env bats
# @covers: hooks/in-progress-label.sh lib/full-autopilot-dispatch.sh hooks/hooks.json hooks/README.md
# =============================================================================
# AT-326: Draft PR 作成時に in-progress 付与 ＋ full-autopilot dispatch の GitHub-state プリフィルタ
# Issue #326
#
#   AT-326-1:  Draft PR 作成時の in-progress 自動付与（F1）
#   AT-326-2:  Issue 番号解決の二経路（body Closes / branch prefix）
#   AT-326-3:  非 Draft / 非対象操作では付与しない（F1 負例）
#   AT-326-4:  Draft PR 放棄（close）時の in-progress 除去（F3）
#   AT-326-5:  冪等性（二重付与・既消去 label 再除去が no-op）
#   AT-326-6:  hook の fail-safe（異常入力でも exit 0・副作用ゼロ）
#   AT-326-7:  dispatch が busy Issue を select から除外（F2）
#   AT-326-8:  プリフィルタは lease 取得前に除外（C2 二重 dispatch 冪等ガード）
#   AT-326-9:  cmd_select の純粋性が保たれる（C1 回帰）
#   AT-326-10: hook 配布・ドキュメント整合（regression 不変量）
#   AT-326-11: デフォルト is_issue_busy の gh pr list 構文が正しく動作する
#
# lifecycle: [regression]
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$ROOT/hooks/in-progress-label.sh"
  DISPATCH="$ROOT/lib/full-autopilot-dispatch.sh"
  LEASE="$ROOT/lib/lease-store.sh"

  # テスト用一時ディレクトリ
  FAKE_BIN="$(mktemp -d)"
  CALL_LOG="$(mktemp)"
  STORE="$(mktemp -d)"
  GIT_BRANCH_MOCK="999-default"

  # モック git
  cat > "$FAKE_BIN/git" <<'GITEOF'
#!/usr/bin/env bash
if [[ "$*" == *"branch --show-current"* ]]; then
  echo "${GIT_BRANCH_MOCK:-999-default}"
  exit 0
fi
exec "$(command -v git 2>/dev/null || echo git)" "$@"
GITEOF
  chmod +x "$FAKE_BIN/git"

  # モック gh（CALL_LOG にログ）
  cat > "$FAKE_BIN/gh" <<'GHEOF'
#!/usr/bin/env bash
echo "$*" >> "${CALL_LOG:-/dev/null}"
if [[ "$*" == *"pr view"* ]] && [[ "$*" == *"headRefName"* ]]; then
  echo "${PR_HEAD_MOCK:-}"
  exit 0
fi
exit 0
GHEOF
  chmod +x "$FAKE_BIN/gh"
}

teardown() {
  rm -rf "$FAKE_BIN" "$CALL_LOG" "$STORE"
}

# フック実行ヘルパー
run_hook() {
  local json="$1"; shift
  local env_vars="PATH=$FAKE_BIN:$PATH CALL_LOG=$CALL_LOG GIT_BRANCH_MOCK=$GIT_BRANCH_MOCK"
  for var in "$@"; do env_vars="$env_vars $var"; done
  eval "env $env_vars bash '$HOOK'" <<< "$json"
}

gh_was_called_with() { grep -qF -- "$1" "$CALL_LOG" 2>/dev/null; }

# fad with busy injection helper
fad_with_busy() {
  local busy_list="$1"; shift
  local stub_file; stub_file="$(mktemp)"
  cat > "$stub_file" <<STUBEOF
#!/usr/bin/env bash
issue="\$1"
for b in $busy_list; do
  [ "\$issue" = "\$b" ] && exit 0
done
exit 1
STUBEOF
  chmod +x "$stub_file"
  LEASE_STORE_DIR="$STORE" FAD_SESSION=dispatcher GITHUB_ACTIONS= FAD_BUSY_CMD="bash $stub_file" \
    bash "$DISPATCH" "$@"
  local ret=$?
  rm -f "$stub_file"
  return $ret
}

# ── AT-326-1: Draft PR 作成時の in-progress 自動付与 ─────────────────────────

@test "AT-326-1: gh pr create --draft with Closes #324 adds in-progress to issue 324" {
  # Given: モック gh/git、Closes #324 を含む draft PR 作成コマンド
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --title \"feat\" --body \"Closes #324\""},"session_id":"s1"}'
  # When: hook の stdin に流す
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  # Then: exit 0 かつ in-progress 付与が 1 回呼ばれる
  [ "$status" -eq 0 ]
  gh_was_called_with "issue edit 324 --add-label in-progress"
}

@test "AT-326-1: hook exits 0 after adding in-progress label" {
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
}

# ── AT-326-2: Issue 番号解決の二経路 ─────────────────────────────────────────

@test "AT-326-2a: Closes #324 in body resolves to issue 324" {
  # Given: branch は別番号（999）だが body に Closes #324 がある
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=999-other" > /dev/null
  gh_was_called_with "issue edit 324 --add-label in-progress"
}

@test "AT-326-2b: branch prefix 324-foo resolves to issue 324 when body has no Closes" {
  # Given: body に Closes なし、ブランチが 324-foo
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"no closes here\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  gh_was_called_with "issue edit 324 --add-label in-progress"
}

@test "AT-326-2c: no Closes and no numeric branch prefix skips label operation" {
  # Given: body に Closes なし、ブランチに数字プレフィックスなし
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"no closes here\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=feature-no-number" > /dev/null
  # Then: add-label も remove-label も呼ばれない
  ! gh_was_called_with "--add-label"
  ! gh_was_called_with "--remove-label"
}

# ── AT-326-3: 非 Draft / 非対象操作では付与しない（負例） ───────────────────

@test "AT-326-3a: gh pr create without --draft does not add label" {
  # Given: --draft フラグなし
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title \"feat\" --body \"Closes #324\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  ! gh_was_called_with "--add-label"
}

@test "AT-326-3b: git status does not add or remove label" {
  local json='{"tool_name":"Bash","tool_input":{"command":"git status"},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  ! gh_was_called_with "--add-label"
  ! gh_was_called_with "--remove-label"
}

# ── AT-326-4: Draft PR 放棄（close）時の in-progress 除去 ────────────────────

@test "AT-326-4a: gh pr close removes in-progress from resolved issue" {
  # Given: 対象ブランチ 324-foo
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr close 324"},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  gh_was_called_with "--remove-label in-progress"
}

@test "AT-326-4b: gh pr merge removes in-progress" {
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr merge 324 --squash"},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  gh_was_called_with "--remove-label in-progress"
}

@test "AT-326-4c: hook exits 0 on close" {
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr close 324"},"session_id":"s1"}'
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
}

# ── AT-326-5: 冪等性 ─────────────────────────────────────────────────────────

@test "AT-326-5a: adding label twice is idempotent (second call also exits 0)" {
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  # 2 回目も exit 0
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
}

@test "AT-326-5b: removing label from issue without label exits 0" {
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr close 324"},"session_id":"s1"}'
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
}

# ── AT-326-6: fail-safe ───────────────────────────────────────────────────────

@test "AT-326-6a: empty stdin exits 0 with no side effects" {
  env PATH="$FAKE_BIN:$PATH" CALL_LOG="$CALL_LOG" GIT_BRANCH_MOCK="324-foo" bash "$HOOK" <<< ""
  [ $? -eq 0 ]
  ! gh_was_called_with "--add-label"
  ! gh_was_called_with "--remove-label"
}

@test "AT-326-6b: malformed JSON exits 0 with no side effects" {
  run run_hook "not-json"
  [ "$status" -eq 0 ]
  ! gh_was_called_with "--add-label"
}

@test "AT-326-6c: non-Bash tool_name exits 0 with no side effects" {
  local json='{"tool_name":"Edit","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
  ! gh_was_called_with "--add-label"
}

@test "AT-326-6d: jq absent exits 0 with no side effects" {
  local NO_JQ_BIN; NO_JQ_BIN="$(mktemp -d)"
  cp "$FAKE_BIN/gh" "$NO_JQ_BIN/gh"
  cp "$FAKE_BIN/git" "$NO_JQ_BIN/git"
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  env PATH="$NO_JQ_BIN" CALL_LOG="$CALL_LOG" GIT_BRANCH_MOCK="324-foo" /bin/bash "$HOOK" <<< "$json"
  local ec=$?
  rm -rf "$NO_JQ_BIN"
  [ "$ec" -eq 0 ]
  ! gh_was_called_with "--add-label"
}

@test "AT-326-6e: gh absent exits 0 with no side effects" {
  local NO_GH_BIN; NO_GH_BIN="$(mktemp -d)"
  cp "$FAKE_BIN/git" "$NO_GH_BIN/git"
  command -v jq >/dev/null 2>&1 && cp "$(command -v jq)" "$NO_GH_BIN/jq"
  local json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  env PATH="$NO_GH_BIN" CALL_LOG="$CALL_LOG" GIT_BRANCH_MOCK="324-foo" /bin/bash "$HOOK" <<< "$json"
  local ec=$?
  rm -rf "$NO_GH_BIN"
  [ "$ec" -eq 0 ]
}

# ── AT-326-7: dispatch が busy Issue を select から除外 ───────────────────────

@test "AT-326-7: busy issue (319) is excluded from select, idle issues (318 320) are selected" {
  # Given: Issue 319 は busy、318 と 320 は idle
  run fad_with_busy "319" select 3 318 319 320
  [ "$status" -eq 0 ]
  # 319 は出力されない
  for line in "${lines[@]}"; do [ "$line" != "319" ]; done
  # 318 と 320 は出力される
  printf '%s\n' "${lines[@]}" | grep -q "^318$"
  printf '%s\n' "${lines[@]}" | grep -q "^320$"
}

# ── AT-326-8: プリフィルタは lease 取得前に除外 ──────────────────────────────

@test "AT-326-8: busy issue does not acquire a lease (prefilter before lease)" {
  # Given: Issue 318 は busy、lease-store は空
  fad_with_busy "318" select 1 318 319 > /dev/null
  # 318 の lease は取得されていない
  run env LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$LEASE" holder issue 318
  [ "$output" = "" ]
  # 319 の lease は取得されている
  run env LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$LEASE" holder issue 319
  [ "$output" = "dispatcher" ]
}

# ── AT-326-9: cmd_select の純粋性（全 idle で既存 FAD-1〜4 が回帰なし） ────────

@test "AT-326-9: all-idle busy stub preserves FAD-1 behavior (first K from unclaimed queue)" {
  # Given: 全 Issue idle（busy スタブ exits 1 always）
  run fad_with_busy "" select 2 318 319 320
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "318" ]
  [ "${lines[1]}" = "319" ]
  [ "${#lines[@]}" -eq 2 ]
}

# ── AT-326-10: hook 配布・ドキュメント整合 ───────────────────────────────────

@test "AT-326-10a: in-progress-label.sh exists and is executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ]
}

@test "AT-326-10b: hooks.json registers in-progress-label.sh in PostToolUse(Bash)" {
  # Given: hooks/hooks.json
  local hooks_json="$ROOT/hooks/hooks.json"
  # When: パース
  jq . "$hooks_json" > /dev/null
  # Then: PostToolUse Bash の hooks 配列に in-progress-label.sh が含まれる
  jq -r '.hooks.PostToolUse[] | .hooks[].command' "$hooks_json" | grep -q "in-progress-label.sh"
}

@test "AT-326-10c: hooks/README.md documents in-progress-label.sh" {
  # Given: hooks/README.md
  local readme="$ROOT/hooks/README.md"
  [ -f "$readme" ]
  grep -q "in-progress-label.sh" "$readme"
}

@test "AT-326-10d: test_hook_distribution.bats passes (hook distribution invariant)" {
  # Given: tests/test_hook_distribution.bats
  local dist_test="$ROOT/tests/test_hook_distribution.bats"
  [ -f "$dist_test" ]
  run bash -c "cd '$ROOT' && bats '$dist_test'"
  [ "$status" -eq 0 ]
}

# ── AT-326-11: デフォルト is_issue_busy の gh pr list 構文（FAD-9 トレーサビリティ） ──

@test "AT-326-11: default is_issue_busy detects open PR via correct shell-variable syntax" {
  # Given: モック gh が issue 318 のブランチ (318-foo) を持つ open PR を返す
  #       FAD_BUSY_CMD は未設定（デフォルト実装パス）
  local fake_bin; fake_bin="$(mktemp -d)"
  cat > "$fake_bin/gh" <<'GHEOF'
#!/usr/bin/env bash
PR_DATA='[{"number":99,"headRefName":"318-foo"}]'
if [[ "$*" == *"pr list"* ]] && [[ "$*" == *"--json"* ]]; then
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

  # When: FAD_BUSY_CMD 未設定でデフォルト実装を通じて select を実行
  run env LEASE_STORE_DIR="$STORE" FAD_SESSION=dispatcher GITHUB_ACTIONS= \
    PATH="$fake_bin:$PATH" \
    bash "$DISPATCH" select 2 318 319 320
  rm -rf "$fake_bin"

  [ "$status" -eq 0 ]
  # Then: 318 は open PR あり → busy → 出力されない
  for line in "${lines[@]}"; do [ "$line" != "318" ]; done
  # 319 と 320 は idle → 出力される
  printf '%s\n' "${lines[@]}" | grep -q "^319$"
  printf '%s\n' "${lines[@]}" | grep -q "^320$"
}
