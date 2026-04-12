#!/usr/bin/env bats

# =============================================================================
# eval-guard.sh — PreToolUse hook tests
# Issue #22: fix false positives from main-side SKILL.md changes and
#            "git push" substring in command arguments
# =============================================================================

GUARD_SCRIPT="hooks/eval-guard.sh"

setup() {
  # Absolute path to guard script (run from repo root)
  GUARD="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/$GUARD_SCRIPT"

  # Create bare remote + working clone to simulate origin/main
  BARE="${BATS_TMPDIR}/eval-guard-bare-$$"
  WORK="${BATS_TMPDIR}/eval-guard-work-$$"

  git init --bare "$BARE" 2>/dev/null
  git clone "$BARE" "$WORK" 2>&1 >/dev/null

  cd "$WORK"
  git config user.email "test@example.com"
  git config user.name "Test"

  # Initial commit on main with a SKILL.md
  mkdir -p skills/session-start
  echo "initial" > skills/session-start/SKILL.md
  echo "readme" > README.md
  git add -A && git commit -m "initial" -q
  git push origin main -q 2>/dev/null

  # Create feature branch
  git checkout -b feature-branch -q

  # Set up eval marker directory
  export XDG_CACHE_HOME="${BATS_TMPDIR}/cache-$$"
  mkdir -p "${XDG_CACHE_HOME}/atdd-kit"
}

teardown() {
  rm -rf "$BARE" "$WORK" "${XDG_CACHE_HOME}"
}

# Helper: run eval-guard with a given command string
run_guard() {
  local cmd="$1"
  local json
  json=$(printf '{"tool_name":"Bash","command":"%s"}' "$cmd")
  cd "$WORK"
  echo "$json" | bash "$GUARD"
}

# Helper: advance origin/main with a SKILL.md change (simulates main progressing)
advance_main_with_skill_change() {
  local adv="${BATS_TMPDIR}/eval-guard-advance-$$"
  git clone "$BARE" "$adv" 2>&1 >/dev/null
  cd "$adv"
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "main update $(date +%s)" > skills/session-start/SKILL.md
  git add -A && git commit -m "main skill update" -q
  git push origin main -q 2>/dev/null
  cd "$WORK"
  git fetch origin -q 2>/dev/null
  rm -rf "$adv"
}

# Helper: make a SKILL.md change on the current branch
change_skill_on_branch() {
  cd "$WORK"
  echo "branch skill change $(date +%s)" > skills/session-start/SKILL.md
  git add -A && git commit -m "branch skill edit" -q
}

# Helper: create eval evidence marker for current branch
create_eval_marker() {
  local branch
  branch=$(cd "$WORK" && git branch --show-current | tr '/' '-')
  touch "${XDG_CACHE_HOME}/atdd-kit/eval-ran-${branch}"
}

# ---------------------------------------------------------------------------
# AC1: merge-base SKILL.md detection — main-side changes must NOT trigger
# ---------------------------------------------------------------------------

@test "AC1: main-side SKILL.md change does not block push (branch has no skill changes)" {
  # Branch only edits README
  cd "$WORK"
  echo "branch readme change" > README.md
  git add README.md && git commit -m "readme edit" -q

  # Main advances with SKILL.md change
  advance_main_with_skill_change

  result=$(run_guard "git push origin feature-branch")
  # Should allow (empty JSON = allow)
  [ "$result" = "{}" ]
}

@test "AC1: main-side SKILL.md change does not block plain git push" {
  cd "$WORK"
  echo "branch readme change" > README.md
  git add README.md && git commit -m "readme edit" -q

  advance_main_with_skill_change

  result=$(run_guard "git push")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC2: Branch-introduced SKILL.md changes ARE detected
# ---------------------------------------------------------------------------

@test "AC2: branch SKILL.md change blocks push when no eval marker" {
  change_skill_on_branch

  result=$(run_guard "git push origin feature-branch")
  echo "$result" | grep -q "permissionDecision"
  echo "$result" | grep -q "deny"
}

@test "AC2: block message contains skill name (session-start)" {
  change_skill_on_branch

  result=$(run_guard "git push origin feature-branch")
  echo "$result" | grep -q "session-start"
}

@test "AC2: branch SKILL.md change allows push when eval marker exists" {
  change_skill_on_branch
  create_eval_marker

  result=$(run_guard "git push origin feature-branch")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC3: "git push" in command arguments must NOT trigger
# ---------------------------------------------------------------------------

@test "AC3: git commit -m with 'git push' in message is not intercepted" {
  change_skill_on_branch

  result=$(run_guard 'git commit -m "fix: remember to git push"')
  [ "$result" = "{}" ]
}

@test "AC3: echo with 'git push' in argument is not intercepted" {
  change_skill_on_branch

  result=$(run_guard 'echo "run git push later"')
  [ "$result" = "{}" ]
}

@test "AC3: grep for 'git push' in a file is not intercepted" {
  change_skill_on_branch

  result=$(run_guard 'grep "git push" README.md')
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC4: Chain commands with real git push ARE detected
# ---------------------------------------------------------------------------

@test "AC4: && chain with git push is intercepted" {
  change_skill_on_branch

  result=$(run_guard "git add . && git push origin feature-branch")
  echo "$result" | grep -q "deny"
}

@test "AC4: semicolon chain with git push is intercepted" {
  change_skill_on_branch

  result=$(run_guard "git add . ; git push")
  echo "$result" | grep -q "deny"
}

@test "AC4: || chain with git push is intercepted" {
  change_skill_on_branch

  result=$(run_guard "git add . || git push")
  echo "$result" | grep -q "deny"
}

@test "AC4: pipe with git push is intercepted" {
  change_skill_on_branch

  result=$(run_guard "echo foo | git push origin feature-branch")
  echo "$result" | grep -q "deny"
}

@test "AC4: git push at start of chain is intercepted" {
  change_skill_on_branch

  result=$(run_guard "git push origin feature-branch && echo done")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# Boundary conditions
# ---------------------------------------------------------------------------

@test "boundary: detached HEAD allows push" {
  cd "$WORK"
  git checkout --detach -q

  result=$(run_guard "git push origin feature-branch")
  [ "$result" = "{}" ]
}

@test "boundary: main branch allows push" {
  cd "$WORK"
  git checkout main -q

  result=$(run_guard "git push origin main")
  [ "$result" = "{}" ]
}

@test "boundary: non-git-push command is not intercepted" {
  change_skill_on_branch

  result=$(run_guard "git status")
  [ "$result" = "{}" ]
}

@test "boundary: empty command is not intercepted" {
  result=$(run_guard "")
  [ "$result" = "{}" ]
}

@test "boundary: git push with extra spaces is intercepted" {
  change_skill_on_branch

  result=$(run_guard "git  push origin feature-branch")
  echo "$result" | grep -q "deny"
}

@test "boundary: git pushall (partial match) is not intercepted" {
  change_skill_on_branch

  result=$(run_guard "git pushall")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# Regression guards
# ---------------------------------------------------------------------------

@test "regression: SKILL.md change on branch + eval marker = allow" {
  change_skill_on_branch
  create_eval_marker

  result=$(run_guard "git add . && git push origin feature-branch")
  [ "$result" = "{}" ]
}

@test "regression: no SKILL.md change on branch = allow" {
  cd "$WORK"
  echo "just readme" > README.md
  git add README.md && git commit -m "readme only" -q

  result=$(run_guard "git push")
  [ "$result" = "{}" ]
}

@test "regression: deny message includes eval guidance" {
  change_skill_on_branch

  result=$(run_guard "git push")
  echo "$result" | grep -q "auto-eval"
}
