#!/usr/bin/env bats

# Tests for Issue #136: autopilot Phase 5 review verification

AUTOPILOT_CMD="commands/autopilot.md"

@test "AC4-136: Phase 5 checks for review PASS comment via gh command" {
  sed -n '/## Phase 5/,/^## [^#]/p' "$AUTOPILOT_CMD" | grep -q 'gh pr view.*comments'
}

@test "AC4-136: Phase 5 STOPs if review PASS not confirmed" {
  sed -n '/## Phase 5/,/^## [^#]/p' "$AUTOPILOT_CMD" | grep -qi 'stop.*merge\|do not.*proceed.*merge'
}
