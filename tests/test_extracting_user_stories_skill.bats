#!/usr/bin/env bats
# @covers: skills/extracting-user-stories/SKILL.md
# Unit Test for the extracting-user-stories skill (#189 / #179 Step B2).
# Per `docs/testing-skills.md` (#222), this is a Unit Test — `claude` is not
# invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/extracting-user-stories.bats`.
#
# Scope (per #189 plan): assert structural gates that protect v1.0 invariants.
#   1. Responsibility boundary — output path, upstream/downstream skill names,
#      no subagent spawn, no in-progress label management
#   2. Line budget — ≤ 200 lines per #216 PRD design rule
#   3. Batch UX — one-message presentation (no 1-story loop)
#   4. Output language — Japanese fixed
#   5. Persona-less invariant — neither SKILL.md nor the template introduces
#      `As a [persona]` patterns
#   6. Template structure — Functional Story + Constraint Story sections

SKILL_FILE="skills/extracting-user-stories/SKILL.md"
TEMPLATE_FILE="templates/docs/issues/user-stories.md"

# --- Responsibility boundary ----------------------------------------------

@test "responsibility: SKILL.md declares output at docs/issues/<NNN>/user-stories.md" {
  grep -q 'docs/issues/<NNN>/user-stories.md' "$SKILL_FILE"
}

@test "responsibility: SKILL.md cites templates/docs/issues/user-stories.md as the source template" {
  grep -q 'templates/docs/issues/user-stories.md' "$SKILL_FILE"
}

@test "responsibility: Upstream is defining-requirements" {
  grep -qE '\*\*Upstream:\*\*[[:space:]]+`defining-requirements`' "$SKILL_FILE"
}

@test "responsibility: Downstream is writing-plan-and-tests (Step 3 ownership)" {
  grep -qE '\*\*Downstream:\*\*[[:space:]]+`writing-plan-and-tests`' "$SKILL_FILE"
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

# --- Batch UX -------------------------------------------------------------

@test "batch UX: SKILL.md mandates one-message batch presentation" {
  grep -qiE 'one message|batch presentation' "$SKILL_FILE"
}

# --- Output language ------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}

# --- Persona-less invariant -----------------------------------------------

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}

@test "no persona: template does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$TEMPLATE_FILE"
}

# --- Template structure ---------------------------------------------------

@test "template: user-stories template has Functional Story heading" {
  grep -qE '^## Functional Story' "$TEMPLATE_FILE"
}

@test "template: user-stories template has Constraint Story heading" {
  grep -qE '^## Constraint Story' "$TEMPLATE_FILE"
}
