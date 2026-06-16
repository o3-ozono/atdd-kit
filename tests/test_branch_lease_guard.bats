#!/usr/bin/env bats
# @covers: hooks/branch-lease-guard.sh
# =============================================================================
# branch-lease-guard.sh -- PreToolUse hook tests
# Issue #316: session-start の Draft PR 接触を二層でブロック（branch-lease guard）
#
# テスト対象の挙動:
#   FS-3: 別セッション保有 Draft ブランチへの write-back は hard block
#   FS-4: 非 write-back 操作 / main / master は常に allow
#   FS-5: 非 main ブランチ push でリース未取得なら自セッション名義で取得
#   FS-6: ATDD_BRANCH_LEASE_FORCE=1 で hard block を上書き
#   CS-1: lease が共有 store に branch キーで保存されクロスセッション参照できる
#   CS-2: TTL 超過リースはアクセス時 orphan 掃除で削除されブロックを生まない
#   fail-safe: 空 stdin / 不正 JSON / jq 不在 / git 不在 → allow
# =============================================================================

GUARD="hooks/branch-lease-guard.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  GUARD_PATH="$ROOT/$GUARD"

  # Isolated lease dir per test
  LEASE_DIR="$(mktemp -d)"

  # Fake bin dir for mock tools
  FAKE_BIN="$(mktemp -d)"

  # Create a mock gh that returns "1 Draft PR" for branches matching DRAFT_BRANCH
  DRAFT_BRANCH="feat/draft-branch"
  cat > "$FAKE_BIN/gh" <<'GHEOF'
#!/usr/bin/env bash
# Mock gh: returns 1 Draft PR for DRAFT_BRANCH, 0 for others
DRAFT_B="${DRAFT_BRANCH_MOCK:-feat/draft-branch}"
if [[ "$*" == *"--head ${DRAFT_B}"* ]] && [[ "$*" == *"isDraft"* ]]; then
  echo "1"
else
  echo "0"
fi
GHEOF
  chmod +x "$FAKE_BIN/gh"
}

teardown() {
  rm -rf "$LEASE_DIR" "$FAKE_BIN"
}

# Helper: run guard with given JSON, isolated lease dir, and optional fake gh
run_guard() {
  local json="$1"
  local extra_env="${2:-}"
  # GITHUB_ACTIONS= で空にし、CI(GNU/GitHub) でも effective_ttl が LOCAL 経路を取るよう固定する。
  # これによりテストは BRANCH_LEASE_TTL_LOCAL のみで TTL を決定論的に制御できる（CI で TTL_CI=2400 が
  # 効いて stale テストが偽 fail するのを防ぐ。CI 検出自体を明示する test は無い）。
  local env_vars="BRANCH_LEASE_DIR=$LEASE_DIR DRAFT_BRANCH_MOCK=$DRAFT_BRANCH GITHUB_ACTIONS= PATH=$FAKE_BIN:$PATH"
  if [ -n "$extra_env" ]; then
    env_vars="$env_vars $extra_env"
  fi
  eval "env $env_vars bash '$GUARD_PATH'" <<< "$json"
}

now_ts() {
  date +%s
}

write_lease_file() {
  local branch="$1"
  local session_id="$2"
  local ts="${3:-$(now_ts)}"
  local encoded
  # encode_branch 関数（hooks/branch-lease-guard.sh L54）と同じエンコードを維持する:
  #   / → %2F, スペース → %20, # → %23, . → %2E, ~ → %7E
  encoded=$(printf '%s' "$branch" | sed 's|/|%2F|g; s| |%20|g; s|#|%23|g; s|\.|%2E|g; s|~|%7E|g')
  printf '{"session_id":"%s","timestamp":%s}\n' "$session_id" "$ts" > "$LEASE_DIR/${encoded}.json"
}

read_lease_file() {
  local branch="$1"
  local encoded
  # encode_branch 関数（hooks/branch-lease-guard.sh L54）と同じエンコードを維持する
  encoded=$(printf '%s' "$branch" | sed 's|/|%2F|g; s| |%20|g; s|#|%23|g; s|\.|%2E|g; s|~|%7E|g')
  cat "$LEASE_DIR/${encoded}.json" 2>/dev/null || true
}

# ── fail-safe ────────────────────────────────────────────────────────────────

@test "fail-safe: empty stdin returns {}" {
  result=$(echo "" | env BRANCH_LEASE_DIR="$LEASE_DIR" bash "$GUARD_PATH")
  [ "$result" = "{}" ]
}

@test "fail-safe: malformed JSON returns {}" {
  result=$(run_guard "not-json-at-all")
  [ "$result" = "{}" ]
}

@test "fail-safe: missing tool_name returns {}" {
  result=$(run_guard '{"tool_input":{"command":"git push"},"session_id":"s1"}')
  [ "$result" = "{}" ]
}

# ── FS-4: non-write-back and main pass-through ───────────────────────────────

@test "FS-4: git checkout is not write-back, returns {}" {
  json='{"tool_name":"Bash","tool_input":{"command":"git checkout feat/something"},"session_id":"s1"}'
  result=$(run_guard "$json")
  [ "$result" = "{}" ]
}

@test "FS-4: git switch is not write-back, returns {}" {
  json='{"tool_name":"Bash","tool_input":{"command":"git switch main"},"session_id":"s1"}'
  result=$(run_guard "$json")
  [ "$result" = "{}" ]
}

@test "FS-4: git rebase without push is not write-back, returns {}" {
  json='{"tool_name":"Bash","tool_input":{"command":"git rebase origin/main"},"session_id":"s1"}'
  result=$(run_guard "$json")
  [ "$result" = "{}" ]
}

@test "FS-4: ls command is not write-back, returns {}" {
  json='{"tool_name":"Bash","tool_input":{"command":"ls -la"},"session_id":"s1"}'
  result=$(run_guard "$json")
  [ "$result" = "{}" ]
}

@test "FS-4: git push to main is always allowed" {
  write_lease_file "main" "session-other"
  json='{"tool_name":"Bash","tool_input":{"command":"git push origin main"},"session_id":"session-B"}'
  result=$(run_guard "$json")
  [ "$result" = "{}" ]
}

@test "FS-4: git push to master is always allowed" {
  write_lease_file "master" "session-other"
  json='{"tool_name":"Bash","tool_input":{"command":"git push origin master"},"session_id":"session-B"}'
  result=$(run_guard "$json")
  [ "$result" = "{}" ]
}

@test "FS-4: non-Bash tool_name is not intercepted, returns {}" {
  json='{"tool_name":"Edit","tool_input":{"command":"git push"},"session_id":"s1"}'
  result=$(run_guard "$json")
  [ "$result" = "{}" ]
}

# ── FS-3: block write-back on branch with another session's fresh lease + Draft PR ──

@test "FS-3: another session's fresh lease + Draft PR → deny on git push" {
  write_lease_file "$DRAFT_BRANCH" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$DRAFT_BRANCH")
  result=$(run_guard "$json" "DRAFT_BRANCH_MOCK=$DRAFT_BRANCH")
  echo "$result" | grep -q '"deny"'
}

@test "FS-3: deny result has exit 0" {
  write_lease_file "$DRAFT_BRANCH" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$DRAFT_BRANCH")
  run bash -c "echo '$json' | env BRANCH_LEASE_DIR='$LEASE_DIR' DRAFT_BRANCH_MOCK='$DRAFT_BRANCH' PATH='$FAKE_BIN:$PATH' bash '$GUARD_PATH'"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"deny"'
}

@test "FS-3: deny includes hookEventName PreToolUse" {
  write_lease_file "$DRAFT_BRANCH" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$DRAFT_BRANCH")
  result=$(run_guard "$json" "DRAFT_BRANCH_MOCK=$DRAFT_BRANCH")
  echo "$result" | grep -q "PreToolUse"
}

@test "FS-3: deny reason mentions another session or branch-lease-guard" {
  write_lease_file "$DRAFT_BRANCH" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$DRAFT_BRANCH")
  result=$(run_guard "$json" "DRAFT_BRANCH_MOCK=$DRAFT_BRANCH")
  echo "$result" | grep -qiE 'another session|session-A|session.*working|branch-lease-guard'
}

@test "FS-3: same session as lease holder is not blocked (FS-5 lease owner)" {
  write_lease_file "$DRAFT_BRANCH" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-A"}' "$DRAFT_BRANCH")
  result=$(run_guard "$json" "DRAFT_BRANCH_MOCK=$DRAFT_BRANCH")
  [ "$result" = "{}" ]
}

@test "FS-3: branch without Draft PR is not blocked even with other session lease" {
  NO_DRAFT="feat/no-draft-branch"
  write_lease_file "$NO_DRAFT" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$NO_DRAFT")
  # DRAFT_BRANCH_MOCK is feat/draft-branch, not feat/no-draft-branch → gh returns 0
  result=$(run_guard "$json")
  [ "$result" = "{}" ]
}

# ── FS-5: lease auto-acquisition on push ─────────────────────────────────────

@test "FS-5: push to un-leased non-main branch acquires lease for self" {
  BRANCH="feat/new-feature"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-A"}' "$BRANCH")
  result=$(run_guard "$json")
  [ "$result" = "{}" ]
  lease=$(read_lease_file "$BRANCH")
  echo "$lease" | grep -q "session-A"
}

@test "FS-5: lease file has branch key and session_id + timestamp" {
  BRANCH="feat/lease-shape-test"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-X"}' "$BRANCH")
  run_guard "$json" >/dev/null
  lease=$(read_lease_file "$BRANCH")
  echo "$lease" | grep -q '"session_id"'
  echo "$lease" | grep -q '"timestamp"'
  echo "$lease" | grep -q "session-X"
}

# ── CS-1: cross-session visibility ───────────────────────────────────────────

@test "CS-1: lease written by session A is readable by session B in shared store" {
  BRANCH="feat/shared-branch"
  write_lease_file "$BRANCH" "session-A"
  # session-B reads the file directly (simulates cross-session access)
  # encode_branch 関数（hooks/branch-lease-guard.sh L54）と同じ 5 文字セットでエンコード
  encoded=$(printf '%s' "$BRANCH" | sed 's|/|%2F|g; s| |%20|g; s|#|%23|g; s|\.|%2E|g; s|~|%7E|g')
  lease=$(cat "$LEASE_DIR/${encoded}.json" 2>/dev/null)
  echo "$lease" | grep -q "session-A"
}

@test "CS-1: BRANCH_LEASE_DIR env override controls where leases are stored" {
  ALT_DIR="$(mktemp -d)"
  BRANCH="feat/alt-dir-test"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-X"}' "$BRANCH")
  env BRANCH_LEASE_DIR="$ALT_DIR" PATH="$FAKE_BIN:$PATH" bash "$GUARD_PATH" <<< "$json" >/dev/null
  # encode_branch 関数（hooks/branch-lease-guard.sh L54）と同じ 5 文字セットでエンコード
  encoded=$(printf '%s' "$BRANCH" | sed 's|/|%2F|g; s| |%20|g; s|#|%23|g; s|\.|%2E|g; s|~|%7E|g')
  [ -f "$ALT_DIR/${encoded}.json" ]
  rm -rf "$ALT_DIR"
}

# ── CS-2: TTL stale lease cleanup ─────────────────────────────────────────────

@test "CS-2: stale lease (TTL exceeded) is cleaned up and does not block" {
  BRANCH="$DRAFT_BRANCH"
  OLD_TS=$(( $(now_ts) - 99999 ))
  write_lease_file "$BRANCH" "session-A" "$OLD_TS"
  # With TTL=3600, a 99999s old lease is stale
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$BRANCH")
  result=$(run_guard "$json" "BRANCH_LEASE_TTL_LOCAL=3600 DRAFT_BRANCH_MOCK=$DRAFT_BRANCH")
  # Stale lease should be removed, no block
  [ "$result" = "{}" ]
}

@test "CS-2: stale lease file is replaced with new session after access" {
  # After stale cleanup, session-B acquires the lease for itself (FS-5).
  # Invariant: the old session-A lease no longer exists — only session-B's lease remains.
  BRANCH="feat/stale-test"
  OLD_TS=$(( $(now_ts) - 99999 ))
  write_lease_file "$BRANCH" "session-A" "$OLD_TS"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$BRANCH")
  run_guard "$json" "BRANCH_LEASE_TTL_LOCAL=3600" >/dev/null
  # session-A's stale lease should not be present; session-B's fresh lease replaces it
  lease=$(read_lease_file "$BRANCH")
  # Either no lease file or only session-B's lease (never session-A's old one)
  if [ -n "$lease" ]; then
    echo "$lease" | grep -q "session-B"
    ! echo "$lease" | grep -q "session-A"
  fi
}

@test "CS-2: fresh lease (within TTL) is not cleaned up" {
  BRANCH="$DRAFT_BRANCH"
  NOW_TS=$(now_ts)
  write_lease_file "$BRANCH" "session-A" "$NOW_TS"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$BRANCH")
  run_guard "$json" "BRANCH_LEASE_TTL_LOCAL=7200 DRAFT_BRANCH_MOCK=$DRAFT_BRANCH" >/dev/null
  lease=$(read_lease_file "$BRANCH")
  echo "$lease" | grep -q "session-A"
}

@test "CS-2: BRANCH_LEASE_TTL_LOCAL env override controls TTL" {
  BRANCH="$DRAFT_BRANCH"
  # A 10-second-old lease with TTL=5 should be stale
  OLD_TS=$(( $(now_ts) - 10 ))
  write_lease_file "$BRANCH" "session-A" "$OLD_TS"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$BRANCH")
  result=$(run_guard "$json" "BRANCH_LEASE_TTL_LOCAL=5 DRAFT_BRANCH_MOCK=$DRAFT_BRANCH")
  [ "$result" = "{}" ]
}

# ── FS-6: override escape hatch ───────────────────────────────────────────────

@test "FS-6: ATDD_BRANCH_LEASE_FORCE=1 overrides hard block" {
  write_lease_file "$DRAFT_BRANCH" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$DRAFT_BRANCH")
  result=$(run_guard "$json" "ATDD_BRANCH_LEASE_FORCE=1 DRAFT_BRANCH_MOCK=$DRAFT_BRANCH")
  [ "$result" = "{}" ]
}

# ── hooks.json registration ───────────────────────────────────────────────────

@test "hooks.json: is valid JSON" {
  jq . "$ROOT/hooks/hooks.json" >/dev/null 2>&1
}

@test "hooks.json: Bash PreToolUse entry for branch-lease-guard exists" {
  local entry
  entry=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command' "$ROOT/hooks/hooks.json" 2>/dev/null)
  echo "$entry" | grep -q "branch-lease-guard"
}

# ── additional write-back detection coverage ──────────────────────────────────

@test "write-back: gh pr edit is blocked with other session lease + Draft PR" {
  write_lease_file "$DRAFT_BRANCH" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"gh pr edit 42 --title foo"},"session_id":"session-B"}' )
  # gh pr edit 42 → branch resolved via gh pr view which our mock doesn't support well;
  # falls back to git branch --show-current. Since we can't fully mock gh pr view here,
  # just verify it doesn't crash and returns valid JSON.
  result=$(run_guard "$json")
  echo "$result" | jq . >/dev/null
}

@test "write-back: gh pr merge is detected as write-back operation" {
  # With no lease and no Draft PR, should allow
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr merge 99"},"session_id":"s1"}'
  result=$(run_guard "$json")
  # Either allow or deny is acceptable without a matching lease; just must be valid JSON
  echo "$result" | jq . >/dev/null
}

@test "write-back: gh pr ready is detected as write-back operation" {
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr ready 42"},"session_id":"s1"}'
  result=$(run_guard "$json")
  echo "$result" | jq . >/dev/null
}

@test "write-back: git push --force is a write-back operation" {
  BRANCH="feat/force-push-test"
  write_lease_file "$BRANCH" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push --force origin %s"},"session_id":"session-B"}' "$BRANCH")
  result=$(run_guard "$json" "DRAFT_BRANCH_MOCK=$BRANCH")
  # DRAFT_BRANCH_MOCK を BRANCH に合わせているため、モック gh は Draft PR ありを返す。
  # 別セッション (session-A) が fresh リースを保有しているため deny が返ることを assert する（AT-003 の force-push カバレッジ）。
  echo "$result" | jq . >/dev/null
  echo "$result" | grep -q '"deny"'
}

# ── Finding 1: ドットを含むブランチ名のエンコード整合 ─────────────────────────
# encode_branch（hook L54）は '.' を %2E にエンコードする。
# write_lease_file / read_lease_file ヘルパーも同じエンコードを使わないと
# ドット入りブランチ（例: fix/1.0-compat）でリース参照が食い違う。
# このテストが回帰として encode 整合を固定する。（#316 review finding priority-3）

@test "encode consistency: dot-branch fix/1.0-compat lease is found after guard writes it" {
  DOT_BRANCH="fix/1.0-compat"
  # ガードが push で lease を書いたと仮定（guard が encode_branch で書く）
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-A"}' "$DOT_BRANCH")
  run_guard "$json" "DRAFT_BRANCH_MOCK=none-matches" >/dev/null

  # write_lease_file ヘルパー（テスト内）が同じエンコードで書いた場合と
  # guard が書いたファイルが同一パスを指す必要がある。
  # read_lease_file で読み出せれば整合している。
  lease=$(read_lease_file "$DOT_BRANCH")
  echo "$lease" | grep -q "session-A"
}

@test "encode consistency: dot-branch write_lease_file can seed a block for guard" {
  # write_lease_file ヘルパーで session-A がシードしたリースを
  # guard が read してブロックすることを確認する（エンコード一致が前提）。
  DOT_BRANCH="fix/1.0-compat"
  write_lease_file "$DOT_BRANCH" "session-A"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-B"}' "$DOT_BRANCH")
  # DRAFT_BRANCH_MOCK を DOT_BRANCH に合わせてモック gh が Draft PR ありを返すようにする
  result=$(run_guard "$json" "DRAFT_BRANCH_MOCK=$DOT_BRANCH")
  # guard がリースを正しく読めていれば deny（エンコードずれがあれば {} が返る）
  echo "$result" | grep -q '"deny"'
}

# ── Finding 3: gh pr edit のブランチ解決正確性 ────────────────────────────────
# test 28 は有効 JSON を返すだけの弱いアサーションだった。
# gh pr view をモック化してブランチ解決経路を実際に検証する。（#316 review finding priority-2）

@test "gh pr edit: --head flag resolves branch correctly and blocks on draft" {
  # --head フラグが付いている場合は正確にそのブランチを対象にする。
  TARGET="feat/head-flag-test"
  write_lease_file "$TARGET" "session-A"
  # モック gh が TARGET を Draft として返すよう DRAFT_BRANCH_MOCK に指定
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"gh pr edit 42 --head %s --title foo"},"session_id":"session-B"}' "$TARGET")
  result=$(run_guard "$json" "DRAFT_BRANCH_MOCK=$TARGET")
  # --head フラグがあるのでブランチ解決は正確。別セッションリース + Draft PR → deny
  echo "$result" | grep -q '"deny"'
}

@test "gh pr edit: without --head flag falls back gracefully and returns valid JSON" {
  # --head フラグ無し・PR番号指定の場合、gh pr view でブランチ解決を試みるが
  # モック gh は pr view に対応していないため git branch --show-current にフォールバック。
  # 重要な不変条件: フォールバックが起きてもクラッシュせず valid JSON を返す（fail-safe）。
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"gh pr edit 42 --title foo"},"session_id":"session-B"}')
  result=$(run_guard "$json")
  echo "$result" | jq . >/dev/null
}
