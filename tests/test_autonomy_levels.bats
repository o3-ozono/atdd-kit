#!/usr/bin/env bats

# AC14: Autonomy Level Recommendation
# Integration test -- verifies consistency across discover SKILL.md,
# workflow-detail.md, autonomy-levels.md, and auto-review.md

# --- Outer loop: autonomy level system exists and is consistent ---

# (discover SKILL.md autonomy level tests removed -- Step 0 was removed in #104)

@test "docs/autonomy-levels.md exists with Level 0-3 definitions" {
  [[ -f docs/autonomy-levels.md ]]
  grep -q 'Level 0' docs/autonomy-levels.md
  grep -q 'Level 1' docs/autonomy-levels.md
  grep -q 'Level 2' docs/autonomy-levels.md
  grep -q 'Level 3' docs/autonomy-levels.md
}

@test "docs/autonomy-levels.md has gate adjustment table" {
  grep -qi 'gate\|approval.*point\|承認ポイント' docs/autonomy-levels.md
}

@test "workflow-detail.md has autonomy labels in Issue Labels table" {
  grep -q 'autonomy:0\|autonomy:1\|autonomy:2\|autonomy:3' docs/workflow-detail.md
}

@test "autopilot.md transitions to ready-to-implement after Plan Review" {
  grep -q 'ready-to-implement' commands/autopilot.md
}

@test "autopilot.md does not require user approval for Plan" {
  ! grep -q 'ready-for-user-approval.*add\|add.*ready-for-user-approval' commands/autopilot.md
}
