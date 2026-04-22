#!/usr/bin/env bats
# @covers: skills/**
# Issue #34 AC6: Workflow skills autopilot-only enforcement (block mode)

DISCOVER="skills/discover/SKILL.md"
PLAN="skills/plan/SKILL.md"
ATDD="skills/atdd/SKILL.md"
VERIFY="skills/verify/SKILL.md"
SHIP="skills/ship/SKILL.md"

@test "AC6: discover AUTOPILOT-GUARD uses STOP" {
  sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER" | grep -qi 'STOP'
}

@test "AC6: plan AUTOPILOT-GUARD uses STOP" {
  sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN" | grep -qi 'STOP'
}

@test "AC6: atdd AUTOPILOT-GUARD uses STOP" {
  sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$ATDD" | grep -qi 'STOP'
}

@test "AC6: verify has AUTOPILOT-GUARD with STOP" {
  grep -q '<AUTOPILOT-GUARD>' "$VERIFY"
  sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$VERIFY" | grep -qi 'STOP'
}

@test "AC6: ship has AUTOPILOT-GUARD with STOP" {
  grep -q '<AUTOPILOT-GUARD>' "$SHIP"
  sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$SHIP" | grep -qi 'STOP'
}

@test "AC6: no AUTOPILOT-GUARD says proceed normally" {
  for skill in "$DISCOVER" "$PLAN" "$ATDD" "$VERIFY" "$SHIP"; do
    ! sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$skill" | grep -qi 'proceed normally'
  done
}
