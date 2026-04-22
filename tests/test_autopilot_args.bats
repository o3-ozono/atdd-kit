#!/usr/bin/env bats
# @covers: commands/autopilot.md
# Issue #125: autopilot argument parsing and plan message unification

# --- AC1: No-argument auto-detection of in-progress Issue ---

@test "AC1: autopilot.md contains in-progress label query for no-arg mode" {
  grep -q 'gh issue list.*--label.*in-progress' commands/autopilot.md
}

@test "AC1: autopilot.md describes auto-detection when no argument given" {
  grep -qi 'no.*arg\|without.*arg\|引数.*なし' commands/autopilot.md ||
  grep -qi 'auto.*detect\|auto-detect' commands/autopilot.md
}

# --- AC2: Issue number argument ---

@test "AC2: autopilot.md describes numeric argument as Issue number" {
  grep -qE 'issue.*number|numeric|number.*issue|#[0-9]' commands/autopilot.md
}

@test "AC2: autopilot.md contains gh issue view for number argument" {
  grep -q 'gh issue view' commands/autopilot.md
}

# --- AC3: Issue name partial match ---

@test "AC3: autopilot.md describes text argument as Issue search" {
  grep -qi 'search\|partial.*match\|部分一致' commands/autopilot.md
}

@test "AC3: autopilot.md contains gh issue list --search for text argument" {
  grep -q 'gh issue list.*--search' commands/autopilot.md
}

# --- AC4: plan completion message unification ---

@test "AC4: plan SKILL.md Step 8 does not offer autopilot review as separate option" {
  ! grep -q 'autopilot review.*for one-shot' skills/plan/SKILL.md
}

@test "AC4: plan SKILL.md Step 8 presents two choices" {
  grep -qE '1\..*/atdd-kit:autopilot|2\..*label|2\..*next' skills/plan/SKILL.md
}

# --- AC5: Multiple in-progress Issues ---

@test "AC5: autopilot.md describes candidate list for multiple Issues" {
  grep -qi 'multiple\|candidate.*list\|choose\|select' commands/autopilot.md
}

# --- AC6: No in-progress Issues found ---

@test "AC6: autopilot.md describes error when no Issue found" {
  grep -qi 'no.*issue.*found\|not found\|error' commands/autopilot.md
}
