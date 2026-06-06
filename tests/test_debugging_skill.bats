#!/usr/bin/env bats
# @covers: skills/debugging/SKILL.md
# Unit Test for the debugging skill (#196 / #179 Step C1).
# Per `docs/guides/testing-skills.md` (#222), this is a Unit Test — `claude` is
# not invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/debugging.bats`.
#
# Scope (per #196 AC): the root-cause-investigation special-flow skill.
#   - Iron Law: no fixes without root cause
#   - HARD-GATE before fix code
#   - 6-step investigation flow + A/B/C classification
#   - 3-failure escalation
#   - Step 6 transitions into the 6-step flow (defining-requirements / running-atdd-cycle)

SKILL_FILE="skills/debugging/SKILL.md"

@test "iron law: SKILL.md states no fixes without root cause investigation" {
  grep -qiE 'NO FIXES WITHOUT ROOT CAUSE' "$SKILL_FILE"
}

@test "hard gate: SKILL.md has a HARD-GATE blocking fix code before root cause" {
  grep -qE '<HARD-GATE>' "$SKILL_FILE"
}

@test "classification: SKILL.md classifies root cause as A/B/C" {
  grep -qiE 'AC Gap' "$SKILL_FILE"
  grep -qiE 'Test Gap' "$SKILL_FILE"
  grep -qiE 'Logic Error' "$SKILL_FILE"
}

@test "escalation: SKILL.md enforces the 3-failure escalation rule" {
  grep -qiE '3-Failure Escalation|3 failed fixes' "$SKILL_FILE"
}

@test "red flags: SKILL.md lists Red Flags that force a STOP" {
  grep -qiE 'Red Flags' "$SKILL_FILE"
}

# --- v1.0 routing (no stale discover reference) ---------------------------

@test "routing: Type A chains to defining-requirements" {
  grep -qE 'defining-requirements' "$SKILL_FILE"
}

@test "routing: Type B/C chains to running-atdd-cycle" {
  grep -qE 'running-atdd-cycle' "$SKILL_FILE"
}

@test "routing: SKILL.md has no stale 'discover' skill reference" {
  ! grep -qiE 'discover' "$SKILL_FILE"
}

# --- Persona-less invariant -----------------------------------------------

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}
