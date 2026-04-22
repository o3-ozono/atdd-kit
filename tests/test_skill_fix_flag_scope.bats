#!/usr/bin/env bats
# @covers: skills/skill-fix/SKILL.md
# AC10: --skill-fix flag scope lock
# discover: accepts --skill-fix (β strategy)
# plan: does NOT accept --skill-fix (HARD-GATE maintained)

DISCOVER="skills/discover/SKILL.md"
PLAN="skills/plan/SKILL.md"

# --- discover: --skill-fix accepted ---

@test "AC10 discover: AUTOPILOT-GUARD contains --skill-fix acceptance" {
  guard_block=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER")
  echo "$guard_block" | grep -q -- '--skill-fix'
}

@test "AC10 discover: HARD-GATE skill-fix exception defined" {
  hard_gate=$(sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER")
  echo "$hard_gate" | grep -q -- '--skill-fix'
}

@test "AC10 discover: Step 7 has --skill-fix bypass branch" {
  grep -q 'skill-fix mode\|--skill-fix.*Skip user approval\|--skill-fix.*step 8' "$DISCOVER"
}

@test "AC10 discover: persona auto-select includes OR --skill-fix" {
  grep -q -- '--autopilot.*OR.*--skill-fix\|--skill-fix.*OR.*--autopilot\|OR.*--skill-fix' "$DISCOVER"
}

# --- plan: --skill-fix NOT accepted (HARD-GATE maintained) ---

@test "AC10 plan: AUTOPILOT-GUARD does NOT accept --skill-fix" {
  guard_block=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN")
  ! echo "$guard_block" | grep -q -- '--skill-fix'
}

@test "AC10 plan: HARD-GATE does NOT have skill-fix exception" {
  hard_gate=$(sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$PLAN")
  ! echo "$hard_gate" | grep -q -- '--skill-fix'
}

@test "AC10 plan: AUTOPILOT-GUARD still requires --autopilot" {
  guard_block=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN")
  echo "$guard_block" | grep -q -- '--autopilot'
}

# --- Structural integrity ---

@test "AC10: discover AUTOPILOT-GUARD still blocks direct invocation with STOP" {
  guard_block=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER")
  echo "$guard_block" | grep -qi 'STOP'
}

@test "AC10: plan AUTOPILOT-GUARD still blocks direct invocation with STOP" {
  guard_block=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN")
  echo "$guard_block" | grep -qi 'STOP'
}
