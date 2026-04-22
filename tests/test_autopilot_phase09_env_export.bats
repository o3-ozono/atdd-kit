#!/usr/bin/env bats
# @covers: commands/autopilot.md
# Issue #111 AC1 / #116 drift-detection: commands/autopilot.md Phase 0.9 Step 4
# documents ATDD_AUTOPILOT_WORKTREE export as optional (not load-bearing).
# cwd-detection is the primary mechanism (#116 fix).
#
# Assertions within the Phase 0.9 section:
#   - ATDD_AUTOPILOT_WORKTREE  (var name present)
#   - export                    (export keyword present, even if marked optional)
#   - realpath                  (canonicalization instruction present)
#   - optional / not load-bearing  (export is NOT mandatory per #116 fix)
#   - cwd-detection             (primary mechanism documented)
#
# Rationale: a plain grep on the whole file can pass even if the section is
# accidentally gutted. Anchoring to the Phase 0.9 heading makes the check
# drift-resistant.

AUTOPILOT_MD="${BATS_TEST_DIRNAME}/../commands/autopilot.md"

extract_phase09() {
  # Print lines between "## Phase 0.9" and the next "## " heading (exclusive).
  awk '
    /^## Phase 0\.9/ { in_block=1; next }
    in_block && /^## / { exit }
    in_block { print }
  ' "$AUTOPILOT_MD"
}

@test "AC1-drift: autopilot.md exists and is readable" {
  [ -f "$AUTOPILOT_MD" ]
}

@test "AC1-drift: Phase 0.9 section exists" {
  grep -q "^## Phase 0\.9" "$AUTOPILOT_MD"
}

@test "AC1-drift: Phase 0.9 mentions ATDD_AUTOPILOT_WORKTREE" {
  extract_phase09 | grep -q "ATDD_AUTOPILOT_WORKTREE"
}

@test "AC1-drift: Phase 0.9 mentions export" {
  extract_phase09 | grep -qi "export"
}

@test "AC1-drift: Phase 0.9 mentions realpath" {
  extract_phase09 | grep -q "realpath"
}

@test "AC1-drift: Phase 0.9 has all three tokens in one section" {
  local section
  section="$(extract_phase09)"
  echo "$section" | grep -q "ATDD_AUTOPILOT_WORKTREE"
  echo "$section" | grep -qi "export"
  echo "$section" | grep -q "realpath"
}

@test "AC1-drift: Phase 0.9 states export is optional (not load-bearing)" {
  # #116 fix: export must be documented as optional, not mandatory
  extract_phase09 | grep -qi "optional"
}

@test "AC1-drift: Phase 0.9 mentions cwd-detection as primary mechanism" {
  # #116 fix: hook auto-detects from stdin cwd
  extract_phase09 | grep -qi "cwd"
}
