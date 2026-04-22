#!/usr/bin/env bats
# @covers: skills/skill-fix/SKILL.md
# AC4 step 6: blocked-ac label flow when quality gates fail
# Tests: MUST-1/2/3, UX U1, Interruption I2 violations, and
# negative assert that ready-to-go is NOT added on gate failure.

SKILL_FIX_SKILL="skills/skill-fix/SKILL.md"
DISCOVER="skills/discover/SKILL.md"
TEMPLATE="templates/workflow/blocked_ac_comment.md"

# --- blocked_ac_comment template exists ---

@test "templates/workflow/blocked_ac_comment.md exists" {
  [[ -f "$TEMPLATE" ]]
}

@test "blocked_ac_comment.md has phase placeholder" {
  grep -qE '\$phase|\{\{phase\}\}|PHASE' "$TEMPLATE"
}

@test "blocked_ac_comment.md has failed_gate placeholder" {
  grep -qE '\$failed_gate|\{\{failed_gate\}\}|FAILED_GATE|failed gate' "$TEMPLATE"
}

@test "blocked_ac_comment.md has reason placeholder" {
  grep -qE '\$reason|\{\{reason\}\}|REASON|reason' "$TEMPLATE"
}

# --- discover SKILL.md: blocked-ac gate enforcement ---

@test "discover SKILL.md documents blocked-ac label on gate FAIL" {
  grep -q 'blocked-ac' "$DISCOVER"
}

@test "discover SKILL.md: MUST-1 check retained under --skill-fix" {
  grep -q 'MUST-1' "$DISCOVER"
}

@test "discover SKILL.md: MUST-2 check retained under --skill-fix" {
  grep -q 'MUST-2' "$DISCOVER"
}

@test "discover SKILL.md: MUST-3 check retained under --skill-fix" {
  grep -q 'MUST-3' "$DISCOVER"
}

@test "discover SKILL.md: UX U1-U5 retained under --skill-fix" {
  grep -q 'U1-U5\|U1.*U5\|UX.*check' "$DISCOVER"
}

@test "discover SKILL.md: Interruption I1-I4 retained under --skill-fix" {
  grep -q 'I1-I4\|I1.*I4\|Interruption.*check' "$DISCOVER"
}

# --- skill-fix SKILL.md: quality gates documented ---

@test "skill-fix SKILL.md documents quality gate retention" {
  grep -q 'MUST-1\|MUST-2\|MUST-3\|quality gate' "$SKILL_FIX_SKILL"
}

@test "skill-fix SKILL.md: blocked-ac label described" {
  grep -q 'blocked-ac' "$SKILL_FIX_SKILL"
}

# --- Negative assert: ready-to-go NOT added on gate failure ---

@test "discover SKILL.md: blocked-ac path does NOT add ready-to-go" {
  # Verify the blocked-ac section does not include ready-to-go
  # (gate FAIL branch should stop before adding ready-to-go)
  blocked_section=$(grep -A5 'blocked-ac' "$DISCOVER" | head -20)
  ! echo "$blocked_section" | grep -q 'add-label ready-to-go'
}

@test "skill-fix SKILL.md: blocked-ac path explicitly excludes ready-to-go" {
  grep -q 'no ready-to-go\|ready-to-go.*付与しない\|exit (no ready' "$SKILL_FIX_SKILL"
}
