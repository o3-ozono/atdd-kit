#!/usr/bin/env bats
# @covers: hooks/in-progress-label.sh
# =============================================================================
# in-progress-label.sh — PostToolUse hook tests
# Issue #326: Draft PR 作成時に in-progress 付与 ＋ close/merge 時に除去
#
#   AT-326-1: Draft PR 作成時に in-progress 付与 (F1)
#   AT-326-2: Issue 番号解決 2 経路 (Closes #N / branch prefix)
#   AT-326-3: --draft 無し / 無関係 Bash では付与しない (F1 負例)
#   AT-326-4: gh pr close 時に in-progress 除去 (F3)
#   AT-326-5: 冪等性 (C2)
#   AT-326-6: fail-safe — 異常入力でも exit 0・副作用ゼロ (C3)
# =============================================================================

HOOK="hooks/in-progress-label.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK_PATH="$ROOT/$HOOK"

  # Fake bin dir for mock gh/git
  FAKE_BIN="$(mktemp -d)"

  # Track which gh calls were made
  CALL_LOG="$(mktemp)"

  # Default branch for git mock (override with GIT_BRANCH_MOCK env)
  GIT_BRANCH_MOCK="999-default"

  # Create mock git
  cat > "$FAKE_BIN/git" <<'GITEOF'
#!/usr/bin/env bash
if [[ "$*" == *"branch --show-current"* ]]; then
  echo "${GIT_BRANCH_MOCK:-999-default}"
  exit 0
fi
# Pass through other git commands to real git
exec "$(command -v git 2>/dev/null || echo git)" "$@"
GITEOF
  chmod +x "$FAKE_BIN/git"

  # Create mock gh that logs calls and always exits 0 (idempotent operations)
  cat > "$FAKE_BIN/gh" <<'GHEOF'
#!/usr/bin/env bash
# Log the call
echo "$*" >> "${CALL_LOG:-/dev/null}"

# Handle gh pr view <num> --json headRefName --jq ...
if [[ "$*" == *"pr view"* ]] && [[ "$*" == *"headRefName"* ]]; then
  # Extract PR number and return branch from PR_HEAD_MOCK env
  echo "${PR_HEAD_MOCK:-}"
  exit 0
fi

exit 0
GHEOF
  chmod +x "$FAKE_BIN/gh"
}

teardown() {
  rm -rf "$FAKE_BIN" "$CALL_LOG"
}

# Run the hook with given JSON input and optional extra env vars
run_hook() {
  local json="$1"
  shift
  local env_vars="PATH=$FAKE_BIN:$PATH CALL_LOG=$CALL_LOG GIT_BRANCH_MOCK=$GIT_BRANCH_MOCK"
  for var in "$@"; do
    env_vars="$env_vars $var"
  done
  eval "env $env_vars bash '$HOOK_PATH'" <<< "$json"
}

# Check if gh was called with specific args (substring match)
# Use -F (fixed-string) and -- to avoid interpreting leading -- as grep flags
gh_was_called_with() {
  grep -qF -- "$1" "$CALL_LOG" 2>/dev/null
}

gh_call_count() {
  grep -cF -- "$1" "$CALL_LOG" 2>/dev/null || echo "0"
}

# ── AT-326-1: Draft PR 作成時に in-progress 付与 ─────────────────────────────

@test "AT-326-1: gh pr create --draft with Closes #324 in body adds in-progress to issue 324" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --title \"feat\" --body \"Closes #324\""},"session_id":"s1"}'
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
  gh_was_called_with "issue edit 324 --add-label in-progress"
}

@test "AT-326-1: hook exits 0 even after adding label" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
}

# ── AT-326-2: Issue 番号解決 2 経路 ──────────────────────────────────────────

@test "AT-326-2: Closes #324 in body resolves to issue 324" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=999-other" > /dev/null
  gh_was_called_with "issue edit 324 --add-label in-progress"
}

@test "AT-326-2: branch prefix 324-foo resolves to issue 324 when no Closes in body" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"no closes here\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  gh_was_called_with "issue edit 324 --add-label in-progress"
}

@test "AT-326-2: no Closes and no numeric branch prefix → no label operation" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"no closes here\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=feature-no-number" > /dev/null
  # No add-label or remove-label should have been called
  ! gh_was_called_with "--add-label"
  ! gh_was_called_with "--remove-label"
}

# ── AT-326-3: --draft 無し / 無関係コマンドでは付与しない ───────────────────

@test "AT-326-3: gh pr create without --draft does not add label" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title \"feat\" --body \"Closes #324\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  ! gh_was_called_with "--add-label"
}

@test "AT-326-3: git status does not add label" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"git status"},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  ! gh_was_called_with "--add-label"
}

@test "AT-326-3: unrelated Bash command does not add or remove label" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"ls -la"},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  ! gh_was_called_with "--add-label"
  ! gh_was_called_with "--remove-label"
}

# ── AT-326-4: gh pr close 時に in-progress 除去 ──────────────────────────────

@test "AT-326-4: gh pr close with numeric PR removes in-progress from resolved issue" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr close 324"},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  gh_was_called_with "--remove-label in-progress"
}

@test "AT-326-4: gh pr merge removes in-progress" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr merge 324 --squash"},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  gh_was_called_with "--remove-label in-progress"
}

@test "AT-326-4: hook exits 0 on close" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr close 324"},"session_id":"s1"}'
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
}

# ── AT-326-5: 冪等性 ─────────────────────────────────────────────────────────

@test "AT-326-5: adding label twice is idempotent (gh returns 0 both times)" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  run_hook "$json" "GIT_BRANCH_MOCK=324-foo" > /dev/null
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  # Second call must also exit 0 (no error from idempotent gh)
  [ "$status" -eq 0 ]
}

@test "AT-326-5: removing label from issue that has no label exits 0 (idempotent close)" {
  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr close 324"},"session_id":"s1"}'
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
}

# ── AT-326-6: fail-safe ───────────────────────────────────────────────────────

@test "AT-326-6: empty stdin exits 0 with no side effects" {
  result=$(env PATH="$FAKE_BIN:$PATH" CALL_LOG="$CALL_LOG" GIT_BRANCH_MOCK="324-foo" bash "$HOOK_PATH" <<< "")
  [ $? -eq 0 ]
  ! gh_was_called_with "--add-label"
  ! gh_was_called_with "--remove-label"
}

@test "AT-326-6: malformed JSON exits 0 with no side effects" {
  run run_hook "not-json"
  [ "$status" -eq 0 ]
  ! gh_was_called_with "--add-label"
}

@test "AT-326-6: non-Bash tool_name exits 0 with no side effects" {
  local json
  json='{"tool_name":"Edit","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  run run_hook "$json" "GIT_BRANCH_MOCK=324-foo"
  [ "$status" -eq 0 ]
  ! gh_was_called_with "--add-label"
}

@test "AT-326-6: jq absent exits 0 with no side effects" {
  # Hide jq by overriding PATH with a dir that has no jq
  local NO_JQ_BIN
  NO_JQ_BIN="$(mktemp -d)"
  # Copy everything from FAKE_BIN except jq-free: just gh and git
  cp "$FAKE_BIN/gh" "$NO_JQ_BIN/gh"
  cp "$FAKE_BIN/git" "$NO_JQ_BIN/git"
  # jq intentionally absent — do NOT copy it

  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  # Use absolute bash path so bash itself is found even without jq in PATH
  result=$(env PATH="$NO_JQ_BIN" CALL_LOG="$CALL_LOG" GIT_BRANCH_MOCK="324-foo" /bin/bash "$HOOK_PATH" <<< "$json")
  local exit_code=$?
  rm -rf "$NO_JQ_BIN"
  [ "$exit_code" -eq 0 ]
  ! gh_was_called_with "--add-label"
}

@test "AT-326-6: gh absent exits 0 with no side effects" {
  local NO_GH_BIN
  NO_GH_BIN="$(mktemp -d)"
  cp "$FAKE_BIN/git" "$NO_GH_BIN/git"
  # gh intentionally absent

  # We need jq available from system
  if command -v jq >/dev/null 2>&1; then
    cp "$(command -v jq)" "$NO_GH_BIN/jq"
  fi

  local json
  json='{"tool_name":"Bash","tool_input":{"command":"gh pr create --draft --body \"Closes #324\""},"session_id":"s1"}'
  # Use absolute bash path so bash itself is found even without gh in PATH
  result=$(env PATH="$NO_GH_BIN" CALL_LOG="$CALL_LOG" GIT_BRANCH_MOCK="324-foo" /bin/bash "$HOOK_PATH" <<< "$json")
  local exit_code=$?
  rm -rf "$NO_GH_BIN"
  [ "$exit_code" -eq 0 ]
  # gh absent → no label calls possible
}
