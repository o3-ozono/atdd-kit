#!/usr/bin/env bats

# AC9: Approval gate integration (discover + plan in one approval)
# AC12: Auto-approval for plan review (autonomy level 1+)
# Integration -- verifies label transitions and gate merging

# --- AC9: discover -> plan inline execution ---

@test "AC9: discover SKILL.md has plan inline execution at final step" {
  grep -qi 'inline.*plan\|plan.*inline\|plan.*core.*flow\|auto.*chain.*plan' skills/discover/SKILL.md
}

@test "AC9: discover SKILL.md produces combined AC + plan output" {
  grep -qi 'AC.*plan.*single\|combined.*comment\|AC.*計画.*まとめ\|AC.*implementation.*plan' skills/discover/SKILL.md
}

@test "AC9: plan SKILL.md has inline mode section" {
  grep -qi 'inline.*mode\|discover.*inline\|インライン' skills/plan/SKILL.md
}

# --- AC12: Auto-approval path ---

@test "AC12: autopilot.md transitions to ready-to-implement after Plan Review" {
  grep -q 'ready-to-implement' commands/autopilot.md
}

@test "AC12: autopilot.md does not use ready-for-user-approval in approval flow" {
  ! grep -q 'add.*ready-for-user-approval' commands/autopilot.md
}

@test "AC12: autopilot.md PO manages review flow" {
  grep -qi 'PO.*review\|PO.*Check\|PO.*横断' commands/autopilot.md
}
