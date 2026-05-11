#!/usr/bin/env bats
# @covers: skills/defining-requirements/SKILL.md
# Skill Acceptance Test (structural) for the defining-requirements skill
# (#188 / #179 Step B1).
#
# Scope (agreed in #188 discover): assert only the two gates that protect
# v1.0 structural invariants.
#   1. Responsibility boundary — output path, downstream skill name, no subagent spawn
#   2. Line budget — ≤ 200 lines per #216 PRD design rule
# Everything else (PRD section coverage, trigger keyword spec, dialog
# discipline, etc.) is verified by the Fast SAT (tests/claude-code/samples/
# fast-defining-requirements.sh) so the LLM checks semantics rather than
# brittle wording.

SKILL_FILE="skills/defining-requirements/SKILL.md"

# --- Responsibility boundary ----------------------------------------------

@test "responsibility: SKILL.md declares output at docs/issues/<NNN>/prd.md" {
  grep -q 'docs/issues/<NNN>/prd.md' "$SKILL_FILE"
}

@test "responsibility: SKILL.md cites templates/docs/issues/prd.md as the source template" {
  grep -q 'templates/docs/issues/prd.md' "$SKILL_FILE"
}

@test "responsibility: Downstream is extracting-user-stories (Step 3 ownership)" {
  grep -qE '\*\*Downstream:\*\*[[:space:]]+`extracting-user-stories`' "$SKILL_FILE"
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
