#!/usr/bin/env bats
# @covers: hooks/main-branch-guard.sh
# =============================================================================
# main-branch-guard.sh -- PreToolUse hook tests
# Issue #38: Enforce Issue-driven workflow via PreToolUse hook (Tier 1)
#
# Prevents Claude from calling Edit/Write/MultiEdit/NotebookEdit on main/master.
# All tests pass stdin JSON in the same format Claude Code delivers to hooks.
#
# NOTE on AC4(b): The matcher "Edit|Write|MultiEdit|NotebookEdit" is evaluated
# by the Claude Code runtime, not by the script itself. Therefore AC4(b)
# ("hook does not run for non-target tools like Bash") cannot be verified by
# BATS alone. It is verified via manual runtime testing after implementation
# (results recorded in PR description).
# =============================================================================

GUARD_SCRIPT="hooks/main-branch-guard.sh"

setup() {
  GUARD="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/$GUARD_SCRIPT"

  # Create a temporary git repository
  WORK="${BATS_TMPDIR}/mbg-work-$$"
  git init -b main "$WORK" 2>/dev/null
  cd "$WORK"
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "initial" > README.md
  git add README.md
  git commit -m "initial" -q
}

teardown() {
  rm -rf "$WORK"
}

# Helper: run main-branch-guard with a given tool name, on current branch
run_guard() {
  local tool="${1:-Edit}"
  local file_path="${2:-/tmp/test.md}"
  local json
  json=$(printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$tool" "$file_path")
  cd "$WORK"
  echo "$json" | bash "$GUARD"
}

# Helper: run guard with raw stdin (for malformed JSON tests)
run_guard_raw() {
  local raw="$1"
  cd "$WORK"
  printf '%s' "$raw" | bash "$GUARD"
}

# ---------------------------------------------------------------------------
# AC6: Fail-safe -- unexpected conditions must not interfere
# ---------------------------------------------------------------------------

@test "AC6: non-git directory returns {}" {
  NON_GIT="${BATS_TMPDIR}/non-git-$$"
  mkdir -p "$NON_GIT"
  local json
  json='{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.md"}}'
  result=$(cd "$NON_GIT" && echo "$json" | bash "$GUARD")
  rm -rf "$NON_GIT"
  [ "$result" = "{}" ]
}

@test "AC6: detached HEAD returns {} with exit 0" {
  cd "$WORK"
  git checkout --detach -q
  run bash -c 'cd '"$WORK"' && echo '"'"'{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.md"}}'"'"' | bash '"$GUARD"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "AC6: git not in PATH returns {}" {
  FAKE_BIN="${BATS_TMPDIR}/fake-bin-$$"
  mkdir -p "$FAKE_BIN"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$FAKE_BIN/git"
  chmod +x "$FAKE_BIN/git"
  local json
  json='{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.md"}}'
  result=$(cd "$WORK" && PATH="$FAKE_BIN:$PATH" bash "$GUARD" <<< "$json")
  rm -rf "$FAKE_BIN"
  [ "$result" = "{}" ]
}

@test "AC6: malformed JSON (not-json) on non-main branch returns {}" {
  # The script does not parse stdin JSON -- it only checks the branch name.
  # On a non-main branch, any stdin (including malformed JSON) passes through.
  cd "$WORK"
  git checkout -b feature/malformed-json-test -q
  result=$(run_guard_raw "not-json")
  [ "$result" = "{}" ]
}

@test "AC6: empty stdin on non-main branch returns {}" {
  # The script does not parse stdin JSON -- it only checks the branch name.
  # On a non-main branch, empty stdin passes through.
  cd "$WORK"
  git checkout -b feature/empty-stdin-test -q
  result=$(run_guard_raw "")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC1: Edit on main branch is denied
# ---------------------------------------------------------------------------

@test "AC1: Edit on main branch returns permissionDecision deny" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "permissionDecision"
  echo "$result" | grep -q "deny"
}

@test "AC1: Edit on main branch exits with status 0" {
  cd "$WORK"
  git checkout main -q
  run bash -c 'cd '"$WORK"' && echo '"'"'{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.md"}}'"'"' | bash '"$GUARD"
  [ "$status" -eq 0 ]
}

@test "AC1: Edit on main branch includes hookEventName PreToolUse" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "PreToolUse"
}

@test "AC1: Edit on main branch includes hookSpecificOutput key" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "hookSpecificOutput"
}

@test "AC1: Edit on main branch is denied for arbitrary file path" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/some/arbitrary/path/file.sh")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# AC3: master branch is denied same as main
# ---------------------------------------------------------------------------

@test "AC3: Edit on master branch returns deny" {
  cd "$WORK"
  git checkout -b master -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "deny"
}

@test "AC3: Edit on master branch includes hookEventName PreToolUse" {
  cd "$WORK"
  git checkout -b master -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "PreToolUse"
}

# ---------------------------------------------------------------------------
# AC5: deny message contains required guidance text
# ---------------------------------------------------------------------------

@test "AC5: deny message contains branch explanation mentioning main" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "main"
}

@test "AC5: deny message contains /atdd-kit:issue guidance" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "atdd-kit:issue"
}

@test "AC5: deny message contains /atdd-kit:autopilot guidance" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "atdd-kit:autopilot"
}

# ---------------------------------------------------------------------------
# AC2: feature and other non-main branches pass through
# ---------------------------------------------------------------------------

@test "AC2: Edit on feature branch returns {}" {
  cd "$WORK"
  git checkout -b feature/my-feature -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

@test "AC2: Edit on develop branch returns {}" {
  cd "$WORK"
  git checkout -b develop -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

@test "AC2: Edit on worktree-autopilot-38 branch returns {}" {
  cd "$WORK"
  git checkout -b worktree-autopilot-38 -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

@test "AC2: Edit on Main (capital M) is not denied -- case-sensitive match" {
  # On macOS (case-insensitive filesystem), creating a branch named 'Main'
  # when 'main' already exists fails. We use 'Mainbranch' as a substitute
  # to test that non-exact matches are not denied.
  cd "$WORK"
  git checkout -b Mainbranch -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

@test "AC2: Edit on MASTER (uppercase) is not denied -- case-sensitive match" {
  cd "$WORK"
  git checkout -b MASTER -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC4(a): all 4 target tools are denied on main
# ---------------------------------------------------------------------------

@test "AC4(a): Write on main branch is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Write")
  echo "$result" | grep -q "deny"
}

@test "AC4(a): MultiEdit on main branch is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "MultiEdit")
  echo "$result" | grep -q "deny"
}

@test "AC4(a): NotebookEdit on main branch is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "NotebookEdit")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# AC4(b) boundary: script does NOT branch on tool_name (branch check only)
# The actual AC4(b) ("hook does not start for Bash tool") is enforced by
# Claude Code's matcher, not by this script. These tests confirm the script
# itself is tool-name-agnostic.
# ---------------------------------------------------------------------------

@test "AC4(b)-boundary: Bash tool_name on main is also denied (script is branch-check-only)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Bash")
  echo "$result" | grep -q "deny"
}

@test "AC4(b)-boundary: Bash tool_name on feature branch returns {}" {
  cd "$WORK"
  git checkout -b feature/test -q
  result=$(run_guard "Bash")
  [ "$result" = "{}" ]
}
