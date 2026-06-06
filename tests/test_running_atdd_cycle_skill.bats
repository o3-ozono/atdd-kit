#!/usr/bin/env bats
# @covers: skills/running-atdd-cycle/SKILL.md
# Unit Test for the running-atdd-cycle skill (#191 / #179 Step B4).
# Per `docs/testing-skills.md` (#222), this is a Unit Test — `claude` is not
# invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/running-atdd-cycle.bats`.
#
# Scope (per #191 AC): assert the C1-C5 ATDD interpretation is mechanically
# encoded, plus the standard responsibility / budget / language gates.
#   C1 — AC as Concrete Examples (Given/When/Then)
#   C2 — AC lifecycle draft -> green -> regression, RED confirmed first
#   C3 — TDD nested inside ATDD
#   C4 — AT is story-scoped / TDD is unit-scoped, files under tests/acceptance/
#   C5 — External (ATDD) and Internal (TDD) feedback loops separated

SKILL_FILE="skills/running-atdd-cycle/SKILL.md"

# --- Responsibility boundary ----------------------------------------------

@test "responsibility: SKILL.md reads docs/issues/<NNN>/plan.md as input" {
  grep -q 'docs/issues/<NNN>/plan.md' "$SKILL_FILE"
}

@test "responsibility: SKILL.md reads docs/issues/<NNN>/acceptance-tests.md as input" {
  grep -q 'docs/issues/<NNN>/acceptance-tests.md' "$SKILL_FILE"
}

@test "responsibility: SKILL.md writes executable AT files under tests/acceptance/" {
  grep -q 'tests/acceptance/' "$SKILL_FILE"
}

@test "responsibility: Upstream is writing-plan-and-tests" {
  grep -qE '\*\*Upstream:\*\*[[:space:]]+`writing-plan-and-tests`' "$SKILL_FILE"
}

@test "responsibility: Downstream is reviewing-deliverables (Step 5 ownership)" {
  grep -qE '\*\*Downstream:\*\*[[:space:]]+`reviewing-deliverables`' "$SKILL_FILE"
}

@test "responsibility: SKILL.md states subagent spawn is out of scope" {
  grep -qE '\*\*does not\*\* spawn reviewer subagents' "$SKILL_FILE"
}

@test "responsibility: SKILL.md states in-progress label management is out of scope" {
  grep -qE '\*\*does not\*\* add or remove the `in-progress` label' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget: SKILL.md is at most 200 lines (#216 PRD design rule)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 200 ]
}

# --- C1: Concrete Examples -------------------------------------------------

@test "C1: SKILL.md treats Acceptance Tests as Concrete Examples (Given/When/Then)" {
  grep -qiE 'concrete example' "$SKILL_FILE"
  grep -qE 'Given' "$SKILL_FILE"
  grep -qE 'When' "$SKILL_FILE"
  grep -qE 'Then' "$SKILL_FILE"
}

# --- C2: lifecycle + RED-first --------------------------------------------

@test "C2: SKILL.md drives AT lifecycle draft -> green -> regression" {
  grep -qi 'draft' "$SKILL_FILE"
  grep -qi 'green' "$SKILL_FILE"
  grep -qi 'regression' "$SKILL_FILE"
}

@test "C2: SKILL.md requires confirming the RED (failing) state before implementing" {
  grep -qE 'RED' "$SKILL_FILE"
}

# --- C3: TDD nested inside ATDD -------------------------------------------

@test "C3: SKILL.md nests the TDD inner loop inside the ATDD cycle" {
  grep -qE 'TDD' "$SKILL_FILE"
  grep -qiE 'nest|inner loop|inside' "$SKILL_FILE"
}

# --- C4: story-scoped AT / unit-scoped TDD --------------------------------

@test "C4: SKILL.md scopes AT files per story" {
  grep -qiE 'story' "$SKILL_FILE"
}

@test "C4: SKILL.md scopes TDD tests per unit" {
  grep -qiE 'unit' "$SKILL_FILE"
}

# --- C5: two separated feedback loops -------------------------------------

@test "C5: SKILL.md separates External (ATDD) and Internal (TDD) feedback loops" {
  grep -qiE 'feedback loop' "$SKILL_FILE"
  grep -qiE 'external|outer' "$SKILL_FILE"
  grep -qiE 'internal|inner' "$SKILL_FILE"
}

# --- Output language ------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}

# --- Persona-less invariant -----------------------------------------------

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}
