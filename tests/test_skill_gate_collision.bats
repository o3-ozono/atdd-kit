#!/usr/bin/env bats
# @covers: scripts/check-issue-collision.sh
# @covers: skills/skill-gate/SKILL.md
# Unit Test for skill-gate parallel collision detection (#197 / #179 Step C2).
#
# skill-gate must detect when another git worktree is already writing the same
# Issue's deliverables (docs/issues/<N>/), emit a clear collision error naming
# the worktree, and NOT false-positive on a different Issue.
#
# The detection mechanism is scripts/check-issue-collision.sh — deterministic,
# no `claude` invocation. These tests build real temp git worktrees.

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/check-issue-collision.sh"

setup() {
  WORK="${BATS_TEST_TMPDIR}/collision"
  MAIN="$WORK/main"
  mkdir -p "$MAIN"
  git -C "$MAIN" init -b main -q
  git -C "$MAIN" config user.email "test@example.com"
  git -C "$MAIN" config user.name "Test"
  mkdir -p "$MAIN/docs/issues"
  echo "base" > "$MAIN/README.md"
  git -C "$MAIN" add -A
  git -C "$MAIN" commit -q -m "base"
  # a second worktree that simulates a parallel session
  WT_A="$WORK/wt-a"
  git -C "$MAIN" worktree add -q "$WT_A" -b feat/parallel-a
}

teardown() {
  rm -rf "$WORK" || true
}

# --- AC: script exists and is executable ---------------------------------

@test "infra: check-issue-collision.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# --- AC: usage errors ----------------------------------------------------

@test "usage: missing --issue exits non-zero" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "usage: non-numeric --issue exits non-zero" {
  run bash "$SCRIPT" --issue abc --self "$MAIN"
  [ "$status" -ne 0 ]
}

# --- AC1: collision detected when another worktree writes same Issue ------

@test "AC1: detects another worktree writing docs/issues/<N>/ (untracked)" {
  mkdir -p "$WT_A/docs/issues/197"
  echo "prd" > "$WT_A/docs/issues/197/prd.md"
  run --separate-stderr bash "$SCRIPT" --issue 197 --self "$MAIN"
  [ "$status" -eq 1 ]
}

@test "AC2: collision error names the Issue and the offending worktree" {
  mkdir -p "$WT_A/docs/issues/197"
  echo "prd" > "$WT_A/docs/issues/197/prd.md"
  run --separate-stderr bash "$SCRIPT" --issue 197 --self "$MAIN"
  echo "$stderr" | grep -qE "Issue #197"
  echo "$stderr" | grep -qiE "in-progress|already"
  echo "$stderr" | grep -qF "$WT_A"
}

@test "AC1: detects committed changes under docs/issues/<N>/ in another worktree" {
  mkdir -p "$WT_A/docs/issues/197"
  echo "prd" > "$WT_A/docs/issues/197/prd.md"
  git -C "$WT_A" add -A
  git -C "$WT_A" commit -q -m "wip 197"
  run --separate-stderr bash "$SCRIPT" --issue 197 --self "$MAIN"
  [ "$status" -eq 1 ]
  echo "$stderr" | grep -qE "Issue #197"
}

# --- AC3: no false positive on a different Issue --------------------------

@test "AC3: different Issue in another worktree does NOT collide" {
  mkdir -p "$WT_A/docs/issues/198"
  echo "prd" > "$WT_A/docs/issues/198/prd.md"
  run --separate-stderr bash "$SCRIPT" --issue 197 --self "$MAIN"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "AC3: no worktree writing the Issue → exit 0" {
  run --separate-stderr bash "$SCRIPT" --issue 197 --self "$MAIN"
  [ "$status" -eq 0 ]
}

# --- self-exclusion: writes in the current worktree are not a collision ---

@test "self: writes under docs/issues/<N>/ in the SELF worktree do not collide" {
  mkdir -p "$MAIN/docs/issues/197"
  echo "prd" > "$MAIN/docs/issues/197/prd.md"
  run --separate-stderr bash "$SCRIPT" --issue 197 --self "$MAIN"
  [ "$status" -eq 0 ]
}

# --- skill-gate wiring ----------------------------------------------------

@test "wiring: skill-gate SKILL.md references the collision check" {
  grep -qE "check-issue-collision\.sh" "$REPO_ROOT/skills/skill-gate/SKILL.md"
}

@test "wiring: skill-gate SKILL.md documents the parallel collision guidance" {
  grep -qiE "collision|parallel|worktree" "$REPO_ROOT/skills/skill-gate/SKILL.md"
}
