#!/usr/bin/env bats

# AC10: --skill-fix flag scope lock
# Verifies that discover SKILL.md accepts --skill-fix (β strategy) and
# plan SKILL.md does NOT accept --skill-fix (HARD-GATE maintained).

DISCOVER="skills/discover/SKILL.md"
PLAN="skills/plan/SKILL.md"

# --- AC10: discover accepts --skill-fix ---

@test "AC10: discover AUTOPILOT-GUARD accepts --skill-fix" {
  sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER" \
    | grep -q -- '--skill-fix'
}

@test "AC10: discover HARD-GATE has Autopilot exception with --skill-fix" {
  sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER" \
    | grep -q -- '--skill-fix'
}

@test "AC10: discover Step 7 has --skill-fix bypass branch" {
  grep -q -- '--skill-fix' "$DISCOVER"
}

@test "AC10: discover persona auto-select has OR --skill-fix condition" {
  grep -q -- '--autopilot.*--skill-fix\|--skill-fix.*--autopilot\|OR.*--skill-fix\|--skill-fix.*OR' "$DISCOVER"
}

# --- AC10: plan does NOT accept --skill-fix (HARD-GATE maintained) ---

@test "AC10: plan AUTOPILOT-GUARD does NOT have --skill-fix bypass" {
  ! sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN" \
    | grep -q -- '--skill-fix'
}

@test "AC10: plan HARD-GATE does NOT have --skill-fix exception" {
  ! sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$PLAN" \
    | grep -q -- '--skill-fix'
}

# --- Structural: discover AUTOPILOT-GUARD still has --autopilot (not replaced) ---

@test "discover AUTOPILOT-GUARD still accepts --autopilot after patch" {
  sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER" \
    | grep -q -- '--autopilot'
}

@test "discover HARD-GATE Autopilot exception still accepts --autopilot" {
  sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER" \
    | grep -q -- '--autopilot'
}

@test "discover AUTOPILOT-GUARD uses STOP" {
  sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER" \
    | grep -qi 'STOP'
}
