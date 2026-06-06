#!/usr/bin/env bats
# @covers: skills/reviewing-deliverables/SKILL.md
# Unit Test for the reviewing-deliverables skill (#192 / #179 Step B5).
# Per `docs/testing-skills.md` (#222), this is a Unit Test — `claude` is not
# invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/reviewing-deliverables.bats`.
#
# Scope (per #192 AC): assert the 6-subagent serial review mechanism plus the
# standard responsibility / budget / language gates.
#   - 6 specialist + aggregator subagents (PRD/US/Plan/Code/AT/Final)
#   - SERIAL execution (#216 PRD Open Question #1: context isolation)
#   - verification completed by Acceptance Tests (no mandatory manual check)
#   - 47 structural criteria across the 5 specialists (#231 integrity fix)

SKILL_FILE="skills/reviewing-deliverables/SKILL.md"

# --- Subagent roster ------------------------------------------------------

@test "subagents: SKILL.md invokes prd-reviewer" {
  grep -q 'prd-reviewer' "$SKILL_FILE"
}

@test "subagents: SKILL.md invokes us-reviewer" {
  grep -q 'us-reviewer' "$SKILL_FILE"
}

@test "subagents: SKILL.md invokes plan-reviewer" {
  grep -q 'plan-reviewer' "$SKILL_FILE"
}

@test "subagents: SKILL.md invokes code-reviewer" {
  grep -q 'code-reviewer' "$SKILL_FILE"
}

@test "subagents: SKILL.md invokes at-reviewer" {
  grep -q 'at-reviewer' "$SKILL_FILE"
}

@test "subagents: SKILL.md invokes final-reviewer" {
  grep -q 'final-reviewer' "$SKILL_FILE"
}

# --- Serial execution -----------------------------------------------------

@test "execution: SKILL.md runs the reviewer subagents serially" {
  grep -qiE 'serial|sequential|one at a time|one-at-a-time' "$SKILL_FILE"
}

# --- Verification via AT --------------------------------------------------

@test "verification: SKILL.md states runtime behavior is verified by Acceptance Tests" {
  grep -qiE 'acceptance test' "$SKILL_FILE"
}

@test "verification: SKILL.md does not mandate manual / preview verification" {
  grep -qiE 'manual' "$SKILL_FILE"
  grep -qiE 'not (require|mandat|force)|no manual|without manual|not mandatory' "$SKILL_FILE"
}

# --- Criteria count integrity ---------------------------------------------

@test "criteria: SKILL.md references the 47-criteria total across the 5 specialists" {
  grep -qE '47' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget: SKILL.md is at most 200 lines (#216 PRD design rule)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 200 ]
}

# --- Responsibility boundary ----------------------------------------------

@test "responsibility: Upstream is running-atdd-cycle" {
  grep -qE '\*\*Upstream:\*\*[[:space:]]+`running-atdd-cycle`' "$SKILL_FILE"
}

@test "responsibility: Downstream is merging-and-deploying (Step 6 ownership)" {
  grep -qE '\*\*Downstream:\*\*[[:space:]]+`merging-and-deploying`' "$SKILL_FILE"
}

@test "responsibility: SKILL.md states in-progress label management is out of scope" {
  grep -qE '\*\*does not\*\* add or remove the `in-progress` label' "$SKILL_FILE"
}

# --- Output language ------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}

# --- Persona-less invariant -----------------------------------------------

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}
