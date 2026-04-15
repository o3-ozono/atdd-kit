#!/usr/bin/env bats

# =============================================================================
# test_autopilot_cb_integration.bats — Integration tests
# Issue #56: autopilot にサーキットブレーカーを導入し無限ループを防止する
#
# AC9: autopilot.md integrates check at revision iteration entry points
# =============================================================================

AUTOPILOT="commands/autopilot.md"

# ---------------------------------------------------------------------------
# AC9(a): Plan Review Round contains CB check
# ---------------------------------------------------------------------------

@test "AC9(a): Plan Review Round contains circuit_breaker.sh check call" {
  sed -n '/^## Plan Review Round/,/^## Phase 3/p' "$AUTOPILOT" | grep -q "circuit_breaker.sh check"
}

@test "AC9(a): Plan Review Round CB check includes non-zero stop instruction" {
  section=$(sed -n '/^## Plan Review Round/,/^## Phase 3/p' "$AUTOPILOT")
  echo "$section" | grep -qi "circuit_breaker.sh check"
  # The section must mention stopping on non-zero exit
  echo "$section" | grep -qiE "non.zero|exit.*[1-9]|stop.*circuit|circuit.*stop|OPEN"
}

# ---------------------------------------------------------------------------
# AC9(b): Phase 3 Implementation contains CB check
# ---------------------------------------------------------------------------

@test "AC9(b): Phase 3 Implementation contains circuit_breaker.sh check call" {
  sed -n '/^## Phase 3: Implementation/,/^## Phase 4/p' "$AUTOPILOT" | grep -q "circuit_breaker.sh check"
}

@test "AC9(b): Phase 3 CB check includes non-zero stop instruction" {
  section=$(sed -n '/^## Phase 3: Implementation/,/^## Phase 4/p' "$AUTOPILOT")
  echo "$section" | grep -qi "circuit_breaker.sh check"
  echo "$section" | grep -qiE "non.zero|exit.*[1-9]|stop.*circuit|circuit.*stop|OPEN"
}

# ---------------------------------------------------------------------------
# AC9(c): Phase 4 PR Review contains CB check
# ---------------------------------------------------------------------------

@test "AC9(c): Phase 4 PR Review contains circuit_breaker.sh check call" {
  sed -n '/^## Phase 4: PR Review/,/^## Phase 5/p' "$AUTOPILOT" | grep -q "circuit_breaker.sh check"
}

# ---------------------------------------------------------------------------
# AC9: trigger events are documented in autopilot.md
# ---------------------------------------------------------------------------

@test "AC9: record_progress trigger documented (SKILL_STATUS: COMPLETE)" {
  grep -q "record_progress" "$AUTOPILOT"
}

@test "AC9: record_no_progress trigger documented" {
  grep -q "record_no_progress" "$AUTOPILOT"
}

@test "AC9: record_error trigger documented" {
  grep -q "record_error" "$AUTOPILOT"
}
