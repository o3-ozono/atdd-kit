#!/usr/bin/env bats
# @covers: docs/**
# tests/test_gh_field_audit.bats
# AC1: gh --json fields are minimized to only what is actually used downstream

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SESSION_START="$REPO_ROOT/skills/session-start/SKILL.md"
# --- session-start/SKILL.md ---

@test "AC1: session-start gh pr view does not request mergeStateStatus (unused field)" {
  run grep "mergeStateStatus" "$SESSION_START"
  # mergeStateStatus should NOT appear anywhere
  [ "$status" -ne 0 ]
}

@test "AC1: session-start gh pr view call exists" {
  run grep "gh pr view" "$SESSION_START"
  [ "$status" -eq 0 ]
}

@test "AC1: session-start gh pr view fetches reviewDecision (used in PR status report)" {
  run grep "reviewDecision" "$SESSION_START"
  [ "$status" -eq 0 ]
}

@test "AC1: session-start gh pr view fetches statusCheckRollup (used in CI status)" {
  run grep "statusCheckRollup" "$SESSION_START"
  [ "$status" -eq 0 ]
}

@test "AC1: session-start gh pr view fetches mergeable (used in conflict detection)" {
  run grep "mergeable" "$SESSION_START"
  [ "$status" -eq 0 ]
}
