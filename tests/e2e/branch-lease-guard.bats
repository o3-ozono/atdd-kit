#!/usr/bin/env bats
# @covers: hooks/branch-lease-guard.sh hooks/hooks.json
# E2E_MODEL=claude-sonnet-4-5
# =============================================================================
# branch-lease-guard E2E tests — Issue #316
#
# End-to-end pin using real lease store + real git branch + mock gh.
# Verifies: another-session Draft branch push is blocked; own-session push passes.
# =============================================================================

GUARD="hooks/branch-lease-guard.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
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
  encoded=$(printf '%s' "$branch" | sed 's|/|%2F|g')
  printf '{"session_id":"%s","timestamp":%s}\n' "$session_id" "$ts" > "$LEASE_DIR/${encoded}.json"
}

run_guard_e2e() {
  local json="$1"
  local extra="${2:-}"
  local base_env="BRANCH_LEASE_DIR=$LEASE_DIR MOCK_DRAFT_BRANCH=$DRAFT_BRANCH PATH=$FAKE_BIN:$PATH"
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
  encoded=$(printf '%s' "$BRANCH" | sed 's|/|%2F|g')
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
