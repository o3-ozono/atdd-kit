#!/usr/bin/env bats

# Issue #111 AC1 drift-detection: commands/autopilot.md Phase 0.9 Step 4 must
# export ATDD_AUTOPILOT_WORKTREE via realpath so the PreToolUse
# autopilot-worktree-guard can enforce the boundary.
#
# Three-token AND assertion within the same Phase 0.9 section:
#   - ATDD_AUTOPILOT_WORKTREE
#   - export
#   - realpath
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
