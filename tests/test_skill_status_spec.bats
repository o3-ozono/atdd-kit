#!/usr/bin/env bats
# @covers: docs/**
# Tests for Issue #58: SKILL_STATUS spec document (AC1)

SPEC_DOC="docs/guides/skill-status-spec.md"

# --- AC1: Spec document exists ---

@test "AC1: docs/guides/skill-status-spec.md exists" {
  [[ -f "$SPEC_DOC" ]]
}

# --- AC1: All 4 fields defined ---

@test "AC1: SKILL_STATUS field is defined" {
  grep -q 'SKILL_STATUS' "$SPEC_DOC"
}

@test "AC1: PHASE field is defined" {
  grep -q 'PHASE' "$SPEC_DOC"
}

@test "AC1: RECOMMENDATION field is defined" {
  grep -q 'RECOMMENDATION' "$SPEC_DOC"
}

# --- AC1: Valid values defined ---

@test "AC1: COMPLETE is listed as a valid value" {
  grep -q 'COMPLETE' "$SPEC_DOC"
}

@test "AC1: PENDING is listed as a valid value" {
  grep -q 'PENDING' "$SPEC_DOC"
}

@test "AC1: BLOCKED is listed as a valid value" {
  grep -q 'BLOCKED' "$SPEC_DOC"
}

@test "AC1: FAILED is listed as a valid value" {
  grep -q 'FAILED' "$SPEC_DOC"
}

# --- AC1: BLOCKED vs FAILED boundary defined ---

@test "AC1: BLOCKED vs FAILED distinction is documented" {
  grep -qi 'blocked.*failed\|failed.*blocked\|distinction\|boundary\|difference\|precondition\|unrecoverable' "$SPEC_DOC"
}

# --- AC1: fenced code block format documented ---

@test "AC1: skill-status fenced code block format is shown" {
  grep -q '```skill-status' "$SPEC_DOC"
}

# --- AC1: fallback rule documented (AC7) ---

@test "AC1: fallback behavior when block is missing is documented" {
  grep -qi 'fallback\|missing\|absent\|no.*block\|block.*not.*found' "$SPEC_DOC"
}

# --- AC1: action matrix documented (AC6) ---

@test "AC1: autopilot action matrix is documented" {
  grep -qi 'action.*matrix\|matrix\|autopilot.*action\|next.*action' "$SPEC_DOC"
}

# --- Issue #162: NEXT_REQUIRED_ACTION optional field ---

@test "AC1(#162): NEXT_REQUIRED_ACTION field is defined" {
  grep -q 'NEXT_REQUIRED_ACTION' "$SPEC_DOC"
}

@test "AC1(#162): NEXT_REQUIRED_ACTION is documented as optional (backward-compatible)" {
  # Fields table should mark it Optional (case-insensitive)
  grep -qi 'NEXT_REQUIRED_ACTION.*Optional\|Optional.*NEXT_REQUIRED_ACTION\| optional\b' "$SPEC_DOC"
}

@test "AC1(#162): NEXT_REQUIRED_ACTION Canonical Source section exists" {
  grep -qi 'Canonical Source' "$SPEC_DOC"
}

@test "AC1(#162): spawn_ac_review_agents is listed as a valid value" {
  grep -q 'spawn_ac_review_agents' "$SPEC_DOC"
}

@test "AC1(#162): Supplementary Dispatch table for COMPLETE is documented" {
  grep -qi 'Supplementary Dispatch' "$SPEC_DOC"
}

@test "AC1(#162): absent NEXT_REQUIRED_ACTION falls back to baseline Action Matrix" {
  # Must state backward-compat: when omitted, falls back to SKILL_STATUS Action Matrix
  grep -qi 'omitted.*baseline\|omitted.*Action Matrix\|absent.*Action Matrix\|fall back.*baseline\|backward.compat' "$SPEC_DOC"
}
