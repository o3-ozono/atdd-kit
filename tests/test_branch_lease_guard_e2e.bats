#!/usr/bin/env bats
# @covers: hooks/branch-lease-guard.sh hooks/hooks.json
# =============================================================================
# branch-lease-guard E2E tests — Issue #316
#
# End-to-end pin using real lease store + real git branch + mock gh.
# Verifies: another-session Draft branch push is blocked; own-session push passes.
# NOTE: This is a hook/guard integration E2E (no `claude -p`), so it lives under
# tests/ alongside test_main_branch_guard.bats — NOT tests/e2e/ which is reserved
# for claude-invoking flow-skill E2E (#278 enforces --model there).
# =============================================================================

GUARD="hooks/branch-lease-guard.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"  # tests/ → repo root（#316: tests/e2e/ から tests/ へ移設したため ../.. → ..）
  GUARD_PATH="$ROOT/$GUARD"

  # Isolated workspace
  WORK="$(mktemp -d)"
  LEASE_DIR="$(mktemp -d)"
  FAKE_BIN="$(mktemp -d)"

  # Real git repo to source branch names
  git init -b main "$WORK/repo" 2>/dev/null
  git -C "$WORK/repo" config user.email "test@example.com"
  git -C "$WORK/repo" config user.name "Test"
  echo "init" > "$WORK/repo/README.md"
  git -C "$WORK/repo" add README.md
  git -C "$WORK/repo" commit -m "init" -q
  git -C "$WORK/repo" checkout -b "feat/e2e-draft-branch" -q

  DRAFT_BRANCH="feat/e2e-draft-branch"

  # Mock gh: returns Draft PR for DRAFT_BRANCH, not for others
  cat > "$FAKE_BIN/gh" <<'GHEOF'
#!/usr/bin/env bash
MOCK_DRAFT="${MOCK_DRAFT_BRANCH:-feat/e2e-draft-branch}"
if [[ "$*" == *"--head ${MOCK_DRAFT}"* ]] && [[ "$*" == *"isDraft"* ]]; then
  echo "1"
else
  echo "0"
fi
GHEOF
  chmod +x "$FAKE_BIN/gh"

  # Provide a fake git (wraps real git) for branch resolution
  # We need git on PATH but also DRAFT_BRANCH to be the current branch in the hook
  # The hook calls `git branch --show-current` as fallback
  cat > "$FAKE_BIN/git" <<GITEOF
#!/usr/bin/env bash
if [[ "\$*" == *"branch --show-current"* ]]; then
  echo "$DRAFT_BRANCH"
elif [[ "\$*" == *"--version"* ]]; then
  echo "git version (mock)"
else
  $(command -v git) "\$@"
fi
GITEOF
  chmod +x "$FAKE_BIN/git"
}

teardown() {
  rm -rf "$WORK" "$LEASE_DIR" "$FAKE_BIN"
}

now_ts() {
  date +%s
}

write_lease() {
  local branch="$1"
  local session_id="$2"
  local ts="${3:-$(now_ts)}"
  local encoded
  # encode_branch（hooks/branch-lease-guard.sh L54）と同じエンコードセットを維持する:
  #   / → %2F, スペース → %20, # → %23, . → %2E, ~ → %7E
  # Finding 1 (#316 review): E2E ヘルパーが '/' のみエンコードしていた場合、
  # ドット入りブランチ（例: fix/1.0-compat）でリース参照がずれてテストが偽パスする。
  encoded=$(printf '%s' "$branch" | sed 's|/|%2F|g; s| |%20|g; s|#|%23|g; s|\.|%2E|g; s|~|%7E|g')
  printf '{"session_id":"%s","timestamp":%s}\n' "$session_id" "$ts" > "$LEASE_DIR/${encoded}.json"
}

run_guard_e2e() {
  local json="$1"
  local extra="${2:-}"
  # GITHUB_ACTIONS= で空にし、CI でも effective_ttl が LOCAL 経路を取るよう固定（unit 側と同じ理由）。
  local base_env="BRANCH_LEASE_DIR=$LEASE_DIR MOCK_DRAFT_BRANCH=$DRAFT_BRANCH GITHUB_ACTIONS= PATH=$FAKE_BIN:$PATH"
  eval "env $base_env $extra bash '$GUARD_PATH'" <<< "$json"
}

# ── E2E-001: another-session Draft branch → push is blocked ──────────────────

@test "E2E-001: another session's fresh lease + Draft branch push is denied" {
  write_lease "$DRAFT_BRANCH" "session-other-e2e" "$(now_ts)"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-mine-e2e"}' "$DRAFT_BRANCH")
  result=$(run_guard_e2e "$json")
  echo "$result" | grep -q '"deny"'
}

# ── E2E-002: own-session push passes through ──────────────────────────────────

@test "E2E-002: own-session push on Draft branch is allowed" {
  write_lease "$DRAFT_BRANCH" "session-mine-e2e" "$(now_ts)"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-mine-e2e"}' "$DRAFT_BRANCH")
  result=$(run_guard_e2e "$json")
  [ "$result" = "{}" ]
}

# ── E2E-003: no lease → auto-acquire + allow ─────────────────────────────────

@test "E2E-003: push with no prior lease acquires lease and allows" {
  BRANCH="feat/e2e-no-lease"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-new-e2e"}' "$BRANCH")
  result=$(run_guard_e2e "$json")
  [ "$result" = "{}" ]
  # encode_branch 関数（hooks/branch-lease-guard.sh L54）と同じ 5 文字セットでエンコード
  encoded=$(printf '%s' "$BRANCH" | sed 's|/|%2F|g; s| |%20|g; s|#|%23|g; s|\.|%2E|g; s|~|%7E|g')
  [ -f "$LEASE_DIR/${encoded}.json" ]
}

# ── E2E-004: non write-back (checkout/rebase) on Draft branch passes ──────────

@test "E2E-004: git checkout on Draft branch is not blocked" {
  write_lease "$DRAFT_BRANCH" "session-other-e2e" "$(now_ts)"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git checkout %s"},"session_id":"session-mine-e2e"}' "$DRAFT_BRANCH")
  result=$(run_guard_e2e "$json")
  [ "$result" = "{}" ]
}

@test "E2E-004: git rebase on Draft branch is not blocked" {
  write_lease "$DRAFT_BRANCH" "session-other-e2e" "$(now_ts)"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git rebase origin/main %s"},"session_id":"session-mine-e2e"}' "$DRAFT_BRANCH")
  result=$(run_guard_e2e "$json")
  [ "$result" = "{}" ]
}

# ── E2E-005: stale lease on Draft branch does not block ──────────────────────

@test "E2E-005: stale other-session lease on Draft branch does not block" {
  OLD_TS=$(( $(now_ts) - 99999 ))
  write_lease "$DRAFT_BRANCH" "session-other-e2e" "$OLD_TS"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-mine-e2e"}' "$DRAFT_BRANCH")
  result=$(run_guard_e2e "$json" "BRANCH_LEASE_TTL_LOCAL=3600")
  [ "$result" = "{}" ]
}

# ── E2E-006: ATDD_BRANCH_LEASE_FORCE=1 overrides block end-to-end ─────────────

@test "E2E-006: ATDD_BRANCH_LEASE_FORCE=1 lets another session push to Draft branch" {
  write_lease "$DRAFT_BRANCH" "session-other-e2e" "$(now_ts)"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-mine-e2e"}' "$DRAFT_BRANCH")
  result=$(run_guard_e2e "$json" "ATDD_BRANCH_LEASE_FORCE=1")
  [ "$result" = "{}" ]
}

# ── E2E-007: ドット入りブランチ名のエンコード整合（Finding 1 regression） ────────
# hooks/branch-lease-guard.sh encode_branch() は '.' を %2E にエンコードする。
# E2E write_lease() ヘルパーが '/' のみエンコードする場合、ドット入りブランチ（例:
# fix/1.0-compat）で guard が書いたリースファイルと write_lease() が書くファイルの
# パスがずれ、ブロックアサーションが偽パス（リース不一致で allow が返る）する。
# このテストは E2E レベルでエンコード整合を回帰固定する。

@test "E2E-007: dot-branch write_lease seeds a block that the guard enforces" {
  DOT_BRANCH="fix/1.0-compat"
  write_lease "$DOT_BRANCH" "session-other-e2e" "$(now_ts)"
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-mine-e2e"}' "$DOT_BRANCH")
  # MOCK_DRAFT_BRANCH を DOT_BRANCH に合わせてモック gh が Draft PR ありを返すようにする
  result=$(run_guard_e2e "$json" "MOCK_DRAFT_BRANCH=$DOT_BRANCH")
  # エンコードが一致していれば guard はリースを検出して deny を返す
  echo "$result" | grep -q '"deny"'
}

@test "E2E-007: dot-branch lease written by guard is readable from write_lease path" {
  DOT_BRANCH="fix/1.0-compat"
  # ガードが push で lease を書く（guard の encode_branch パスで書き込む）
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin %s"},"session_id":"session-writer-e2e"}' "$DOT_BRANCH")
  run_guard_e2e "$json" "MOCK_DRAFT_BRANCH=none" >/dev/null
  # write_lease ヘルパーのエンコードパスで読み出せることを確認する
  encoded=$(printf '%s' "$DOT_BRANCH" | sed 's|/|%2F|g; s| |%20|g; s|#|%23|g; s|\.|%2E|g; s|~|%7E|g')
  [ -f "$LEASE_DIR/${encoded}.json" ]
  grep -q "session-writer-e2e" "$LEASE_DIR/${encoded}.json"
}
