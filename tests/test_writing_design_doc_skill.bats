#!/usr/bin/env bats
# @covers: skills/writing-design-doc/SKILL.md
# Unit Test for the writing-design-doc skill (#195 / #179 Step B8).
# Per `docs/guides/testing-skills.md` (#222), this is a Unit Test — `claude` is
# not invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/writing-design-doc.bats`.
#
# Scope (per #195 AC): on-demand, conditional design-doc generator.
#   - output to docs/issues/NNN/design-doc.md
#   - Ubl 2020 sections: Context/Goals/Non-Goals/Design/Trade-offs/Alternatives/Open Questions
#   - conditional (only when trade-offs / alternatives exist)

SKILL_FILE="skills/writing-design-doc/SKILL.md"

# --- Implemented (no longer a skeleton) -----------------------------------

@test "implemented: SKILL.md no longer carries the not-yet-implemented gate" {
  ! grep -q 'not yet implemented' "$SKILL_FILE"
  ! grep -q '<HARD-GATE>' "$SKILL_FILE"
}

# --- Frontmatter ----------------------------------------------------------

@test "frontmatter: description starts with Use when" {
  local desc
  desc=$(grep '^description:' "$SKILL_FILE" | sed 's/^description:[[:space:]]*//' | tr -d '"')
  [[ "$desc" == "Use when"* ]]
}

# --- Output path ----------------------------------------------------------

@test "output: design doc is written to docs/issues/<NNN>/design-doc.md" {
  grep -qE 'docs/issues/<NNN>/design-doc\.md' "$SKILL_FILE"
}

# --- Ubl 2020 structure ---------------------------------------------------

@test "ubl: SKILL.md documents the Ubl 2020 section set" {
  grep -qi 'Ubl 2020' "$SKILL_FILE"
  grep -qiE 'Context' "$SKILL_FILE"
  grep -qiE 'Goals' "$SKILL_FILE"
  grep -qiE 'Non-Goals' "$SKILL_FILE"
  grep -qiE 'Design' "$SKILL_FILE"
  grep -qiE 'Trade-offs' "$SKILL_FILE"
  grep -qiE 'Alternatives' "$SKILL_FILE"
  grep -qiE 'Open Questions' "$SKILL_FILE"
}

# --- Conditional use ------------------------------------------------------

@test "conditional: SKILL.md says skip when the design is obvious" {
  grep -qiE 'skip' "$SKILL_FILE"
  grep -qiE 'trade-off|alternative' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget: SKILL.md is at most 200 lines (#216 PRD design rule)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 200 ]
}

# --- Output language ------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}

# --- Integration ----------------------------------------------------------

@test "integration: SKILL.md has Upstream and Downstream lines" {
  grep -qE '\*\*Upstream:\*\*' "$SKILL_FILE"
  grep -qE '\*\*Downstream:\*\*' "$SKILL_FILE"
}

# --- Persona-less invariant -----------------------------------------------

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}
