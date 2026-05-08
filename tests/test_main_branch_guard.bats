#!/usr/bin/env bats
# @covers: hooks/main-branch-guard.sh hooks/main_branch_guard.py
# =============================================================================
# main-branch-guard.sh -- PreToolUse hook tests
# Issue #38: Enforce Issue-driven workflow via PreToolUse hook (Tier 1)
# Issue #181: Allow-list for repo-external paths + skill-agnostic deny message
#
# Prevents Claude from calling Edit/Write/MultiEdit/NotebookEdit on main/master
# for repo-managed files. Allows edits to /tmp, /var/folders, ~/.claude,
# ~/.config, /dev/null even on main/master.
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
# Default file_path is a fixed non-allow-list path so deny tests work on macOS
# (BATS_TMPDIR resolves to /private/var/folders/... which is in the allow-list)
run_guard() {
  local tool="${1:-Edit}"
  local file_path="${2:-/some/repo/file.md}"
  local json
  json=$(printf '{"tool_name":"%s","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$tool" "$file_path" "$WORK")
  cd "$WORK"
  echo "$json" | bash "$GUARD"
}

# Helper: run guard for NotebookEdit (uses notebook_path key)
# Default notebook_path is a fixed non-allow-list path for deny tests
run_guard_nb() {
  local file_path="${1:-/some/repo/notebook.ipynb}"
  local json
  json=$(printf '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"%s"},"cwd":"%s"}' "$file_path" "$WORK")
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

@test "AC6: malformed JSON on non-main branch returns {}" {
  # On a non-main branch any stdin passes through (branch check only for non-main).
  cd "$WORK"
  git checkout -b feature/malformed-json-test -q
  result=$(run_guard_raw "not-json")
  [ "$result" = "{}" ]
}

@test "AC6: empty stdin on non-main branch returns {}" {
  # On a non-main branch empty stdin passes through.
  cd "$WORK"
  git checkout -b feature/empty-stdin-test -q
  result=$(run_guard_raw "")
  [ "$result" = "{}" ]
}

@test "AC6: malformed JSON on main branch returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard_raw "not-json")
  [ "$result" = "{}" ]
}

@test "AC6: empty stdin on main branch returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard_raw "")
  [ "$result" = "{}" ]
}

@test "AC6: python3 not in PATH on main branch returns {} (fail-safe)" {
  FAKE_BIN="${BATS_TMPDIR}/fake-bin-py-$$"
  mkdir -p "$FAKE_BIN"
  # stub git so branch detection works; python3 is absent from FAKE_BIN
  printf '#!/bin/bash\nif [ "$1" = "branch" ]; then echo "main"; fi\n' > "$FAKE_BIN/git"
  chmod +x "$FAKE_BIN/git"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/README.md"},"cwd":"%s"}' "$WORK" "$WORK")
  # prepend FAKE_BIN so fake git takes precedence and python3 is not found there
  result=$(cd "$WORK" && PATH="$FAKE_BIN:$PATH" /bin/bash "$GUARD" <<< "$json")
  rm -rf "$FAKE_BIN"
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC1 (Issue #38): Edit on main branch with repo file is denied
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
  run bash -c 'cd '"$WORK"' && printf '"'"'{"tool_name":"Edit","tool_input":{"file_path":"/some/repo/file.md"},"cwd":"'"$WORK"'"}'"'"' | bash '"$GUARD"
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

@test "AC1: Edit on main branch is denied for arbitrary non-allow-list path" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/some/arbitrary/path/file.sh")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# AC3 (Issue #38): master branch is denied same as main
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
# AC4 (Issue #181): deny message is skill-name-agnostic
# ---------------------------------------------------------------------------

@test "AC4: deny message contains branch explanation mentioning main" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "main"
}

@test "AC4: deny message does NOT contain /atdd-kit:issue" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  if echo "$result" | grep -q "atdd-kit:issue"; then
    echo "FAIL: deny message contains atdd-kit:issue skill name"
    return 1
  fi
}

@test "AC4: deny message does NOT contain /atdd-kit:autopilot" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  if echo "$result" | grep -q "atdd-kit:autopilot"; then
    echo "FAIL: deny message contains atdd-kit:autopilot skill name"
    return 1
  fi
}

@test "AC4: deny message mentions Issue-driven workflow" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "Issue"
}

# ---------------------------------------------------------------------------
# AC2 (Issue #38): feature and other non-main branches pass through
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
# AC4(a) (Issue #38): all 4 target tools are denied on main for repo files
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

@test "AC4(a): NotebookEdit on main branch is denied (file_path key)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "NotebookEdit")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# AC4(b) boundary: new py helper checks tool_name; only Edit/Write/MultiEdit/
# NotebookEdit trigger allow-list check; other tools are immediately allowed.
# The actual AC4(b) ("hook does not start for Bash tool") is enforced by
# Claude Code's matcher, not by this script.
# ---------------------------------------------------------------------------

@test "AC4(b)-boundary: Bash tool_name on main returns {} (script allows non-target tools)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Bash")
  [ "$result" = "{}" ]
}

@test "AC4(b)-boundary: Bash tool_name on feature branch returns {}" {
  cd "$WORK"
  git checkout -b feature/test -q
  result=$(run_guard "Bash")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC1 (Issue #181): Allow-list passes throwaway temp paths on main
# ---------------------------------------------------------------------------

@test "AC1(#181): Edit /tmp/foo.md on main returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/tmp/foo.md")
  [ "$result" = "{}" ]
}

@test "AC1(#181): Write /tmp/foo.md on main returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Write" "/tmp/foo.md")
  [ "$result" = "{}" ]
}

@test "AC1(#181): MultiEdit /tmp/foo.md on main returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "MultiEdit" "/tmp/foo.md")
  [ "$result" = "{}" ]
}

@test "AC1(#181): NotebookEdit /tmp/nb.ipynb on main returns {} (file_path key)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "NotebookEdit" "/tmp/nb.ipynb")
  [ "$result" = "{}" ]
}

@test "AC1(#181): NotebookEdit /tmp/nb.ipynb on main returns {} (notebook_path key)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard_nb "/tmp/nb.ipynb")
  [ "$result" = "{}" ]
}

@test "AC1(#181): Edit /private/tmp/foo.md on main returns {} (macOS realpath)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/private/tmp/foo.md")
  [ "$result" = "{}" ]
}

@test "AC1(#181): Edit /dev/null on main returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/dev/null")
  [ "$result" = "{}" ]
}

@test "AC1(#181): Edit BATS_TMPDIR path on main returns {} (under /var/folders or /private/var/folders)" {
  cd "$WORK"
  git checkout main -q
  # BATS_TMPDIR is typically /var/folders/... on macOS or /tmp on Linux
  local tmpfile
  tmpfile=$(mktemp)
  result=$(run_guard "Edit" "$tmpfile")
  rm -f "$tmpfile"
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC2 (Issue #181): Allow-list passes user config dirs on main
# ---------------------------------------------------------------------------

@test "AC2(#181): Edit ~/.claude/config.yml on main returns {} (HOME override)" {
  cd "$WORK"
  git checkout main -q
  # Use WORK as fake HOME so ~/.claude resolves to $WORK/.claude/
  local fake_home="$WORK"
  mkdir -p "$fake_home/.claude"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"~/.claude/config.yml"},"cwd":"%s"}' "$WORK")
  result=$(cd "$WORK" && env HOME="$fake_home" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AC2(#181): Edit ~/.config/foo on main returns {} (HOME override)" {
  cd "$WORK"
  git checkout main -q
  local fake_home="$WORK"
  mkdir -p "$fake_home/.config"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"~/.config/foo"},"cwd":"%s"}' "$WORK")
  result=$(cd "$WORK" && env HOME="$fake_home" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AC2(#181): Edit absolute ~/.claude path on main returns {} (HOME override)" {
  cd "$WORK"
  git checkout main -q
  local fake_home="$WORK"
  mkdir -p "$fake_home/.claude"
  local dotclaude_path
  dotclaude_path="$fake_home/.claude/settings.json"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$dotclaude_path" "$WORK")
  result=$(cd "$WORK" && env HOME="$fake_home" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC3 (Issue #181): Repo-managed file edit on main is still denied
# ---------------------------------------------------------------------------

@test "AC3(#181): Edit repo README.md on main is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/some/repo/README.md")
  echo "$result" | grep -q "deny"
}

@test "AC3(#181): Write to arbitrary non-allow-list path on main is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Write" "/some/arbitrary/path/file.sh")
  echo "$result" | grep -q "deny"
}

@test "AC3(#181): NotebookEdit repo notebook on main is denied (notebook_path key)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard_nb "/some/repo/notebook.ipynb")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# AC5 (Issue #181): Boundary cases -- prefix trap and traversal
# ---------------------------------------------------------------------------

@test "AC5(#181): /tmpfoo on main is denied (prefix trap)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/tmpfoo")
  echo "$result" | grep -q "deny"
}

@test "AC5(#181): /var/foldersx/foo on main is denied (prefix trap)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/var/foldersx/foo")
  echo "$result" | grep -q "deny"
}

@test "AC5(#181): /tmp/../etc/passwd on main is denied (traversal outside allow-list)" {
  cd "$WORK"
  git checkout main -q
  # realpath resolves /tmp/../etc/passwd -> /etc/passwd (outside allow-list)
  result=$(run_guard "Edit" "/tmp/../etc/passwd")
  echo "$result" | grep -q "deny"
}

@test "AC5(#181): /tmp/../tmp/foo on main returns {} (traversal stays in allow-list)" {
  cd "$WORK"
  git checkout main -q
  # realpath resolves /tmp/../tmp/foo -> /tmp/foo (stays in allow-list)
  result=$(run_guard "Edit" "/tmp/../tmp/foo")
  [ "$result" = "{}" ]
}
