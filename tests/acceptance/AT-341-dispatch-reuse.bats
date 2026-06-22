#!/usr/bin/env bats
# @covers: skills/batch-discovery/SKILL.md lib/full-autopilot-dispatch.sh
# AT-341-B/C: batch 壁打ち + parallel dispatch (FS-2 / FS-3 / FS-4 / FS-5)
# Issue #341
#
# B-tests: SKILL.md records the batched 壁打ち contract (autonomous draft + human-only points).
# C-tests: lib/full-autopilot-dispatch.sh select respects K slots and skips busy Issues.
#
# lifecycle: [green]

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

setup() {
  REPO="$(repo_root)"
  SKILL="${REPO}/skills/batch-discovery/SKILL.md"
  DISPATCH_LIB="${REPO}/lib/full-autopilot-dispatch.sh"
  TMP="$(mktemp -d)"
  export LEASE_STORE_DIR="$TMP/leases"
  mkdir -p "$LEASE_STORE_DIR"
}

teardown() {
  rm -rf "$TMP"
}

# ---------------------------------------------------------------------------
# AT-341-B1: SKILL.md autonomous draft + human-only decision points
# ---------------------------------------------------------------------------

@test "AT-341-B1: SKILL.md states derivable requirements are autonomously drafted without asking human" {
  grep -qiE 'autonomous.*draft|do not ask|not ask.*human' "$SKILL"
}

@test "AT-341-B1: SKILL.md lists tradeoffs as a human-only decision kind" {
  grep -qiE 'Tradeoff|tradeoffs|trade-off' "$SKILL"
}

@test "AT-341-B1: SKILL.md lists intentional cut-corners as a human-only decision kind" {
  grep -qiE 'cut-corner|intentional' "$SKILL"
}

@test "AT-341-B1: SKILL.md lists scope exclusions as a human-only decision kind" {
  grep -qiE 'Scope exclusion|scope-exclusion' "$SKILL"
}

@test "AT-341-B1: SKILL.md lists risk tolerance as a human-only decision kind" {
  grep -qiE 'risk.*tolerance|Risk tolerance' "$SKILL"
}

@test "AT-341-B1: SKILL.md lists acceptance criteria as a human-only decision kind" {
  grep -qiE 'Acceptance criteria|acceptance criterion' "$SKILL"
}

@test "AT-341-B1: SKILL.md batches questions across all Issues in one human session" {
  grep -qiE '1 human session|single human session|all N Issues.*once' "$SKILL"
}

@test "AT-341-B2: SKILL.md defines human gate count as constant (not per-Issue)" {
  grep -qiE 'constant|non-proportional' "$SKILL"
}

@test "AT-341-B2: SKILL.md explicitly excludes per-Issue sequential batching" {
  grep -qiE 'per-Issue.*excluded|not.*per-Issue|sequential.*excluded' "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-341-C1: dispatch lib select -- K-slot + busy skip
# ---------------------------------------------------------------------------

@test "AT-341-C1: lib/full-autopilot-dispatch.sh exists" {
  test -f "$DISPATCH_LIB"
}

@test "AT-341-C1: SKILL.md mentions lib/full-autopilot-dispatch.sh select as the dispatch path" {
  grep -q 'full-autopilot-dispatch.sh' "$SKILL"
  grep -q 'select' "$SKILL"
}

@test "AT-341-C1: dispatch select acquires at most K leases from idle Issues (busy injected via script)" {
  # Given: Issues 11 12 are idle; 13 14 are busy. K=2.
  # FAD_BUSY_CMD must be a script path — no shell quoting issues.
  local busy_script="$TMP/busy_cmd.sh"
  printf '#!/bin/sh\ncase "$1" in 13|14) exit 0;; *) exit 1;; esac\n' > "$busy_script"
  chmod +x "$busy_script"
  export FAD_SESSION="test-session-c1a"
  export FAD_BUSY_CMD="$busy_script"
  run bash "$DISPATCH_LIB" select 2 11 12 13 14
  # Then: exactly 2 Issues selected (11 and 12, the idle ones)
  [ "$status" -eq 0 ]
  local count
  count=$(printf '%s\n' "$output" | grep -c '^[0-9]' || true)
  [ "$count" -eq 2 ]
  printf '%s\n' "$output" | grep -q '^11$'
  printf '%s\n' "$output" | grep -q '^12$'
}

@test "AT-341-C1: dispatch select skips busy Issues and selects zero when all are busy" {
  # Given: all Issues are busy. K=2.
  local busy_script="$TMP/all_busy.sh"
  printf '#!/bin/sh\nexit 0\n' > "$busy_script"
  chmod +x "$busy_script"
  export FAD_SESSION="test-session-c1b"
  export FAD_BUSY_CMD="$busy_script"
  run bash "$DISPATCH_LIB" select 2 21 22
  # Then: no Issues selected (all busy)
  [ "$status" -eq 0 ]
  local count
  count=$(printf '%s\n' "$output" | grep -c '^[0-9]' || true)
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AT-341-C2: worker startup -- worktree + settings seeding
# ---------------------------------------------------------------------------

@test "AT-341-C2: SKILL.md worker startup mentions worktree isolation" {
  grep -qiE 'worktree.*isolat|isolated worktree|1 issue.*1 worktree' "$SKILL"
}

@test "AT-341-C2: SKILL.md worker startup mentions plugin settings seeding" {
  grep -qiE 'seed.*plugin|settings.*seed|__seed_worktree_settings' "$SKILL"
}

@test "AT-341-C2: SKILL.md warns that missing seed causes Unknown-command instant death" {
  grep -qiE 'Unknown command' "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-341-C3: worker lifecycle -- lease release on 3 paths
# ---------------------------------------------------------------------------

@test "AT-341-C3: SKILL.md worker lifecycle lists normal-completion lease release" {
  grep -qiE 'Normal completion|normal.*release' "$SKILL"
}

@test "AT-341-C3: SKILL.md worker lifecycle lists failure/timeout lease release" {
  grep -qiE 'failure.*timeout|timeout.*failure|failure.*release' "$SKILL"
}

@test "AT-341-C3: SKILL.md worker lifecycle lists TTL as last-resort lease reclaim for crashes" {
  grep -qiE 'TTL.*last|last.*TTL|LEASE_TTL' "$SKILL"
}
