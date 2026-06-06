#!/usr/bin/env bats
# @covers: skills/writing-plan-and-tests/SKILL.md
# Unit Test for the writing-plan-and-tests skill (#190 / #179 Step B3).
# Per `docs/testing-skills.md` (#222), this is a Unit Test — `claude` is not
# invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/writing-plan-and-tests.bats`.
#
# Scope (per #190 AC): assert structural gates that protect v1.0 invariants.
#   1. Responsibility boundary — input/output paths, template citations,
#      upstream/downstream skill names, no subagent spawn, no in-progress label
#   2. Line budget — ≤ 200 lines per #216 PRD design rule
#   3. Plan granularity — 2-5 minute tasks each paired with a verify step
#   4. AT lifecycle — planned → draft → green → regression encoded
#   5. design-doc conditionality — produced only on trade-offs / alternatives
#   6. Output language — Japanese fixed
#   7. Persona-less invariant — neither SKILL.md nor templates introduce
#      `As a [persona]` patterns
#   8. Template structure — plan (Implementation/Testing/Finishing + verify),
#      acceptance-tests (lifecycle state markers)

SKILL_FILE="skills/writing-plan-and-tests/SKILL.md"
PLAN_TEMPLATE="templates/docs/issues/plan.md"
AT_TEMPLATE="templates/docs/issues/acceptance-tests.md"

# --- Responsibility boundary ----------------------------------------------

@test "responsibility: SKILL.md reads docs/issues/<NNN>/user-stories.md as input" {
  grep -q 'docs/issues/<NNN>/user-stories.md' "$SKILL_FILE"
}

@test "responsibility: SKILL.md declares plan output at docs/issues/<NNN>/plan.md" {
  grep -q 'docs/issues/<NNN>/plan.md' "$SKILL_FILE"
}

@test "responsibility: SKILL.md declares AT output at docs/issues/<NNN>/acceptance-tests.md" {
  grep -q 'docs/issues/<NNN>/acceptance-tests.md' "$SKILL_FILE"
}

@test "responsibility: SKILL.md cites templates/docs/issues/plan.md as the source template" {
  grep -q 'templates/docs/issues/plan.md' "$SKILL_FILE"
}

@test "responsibility: SKILL.md cites templates/docs/issues/acceptance-tests.md as the source template" {
  grep -q 'templates/docs/issues/acceptance-tests.md' "$SKILL_FILE"
}

@test "responsibility: Upstream is extracting-user-stories" {
  grep -qE '\*\*Upstream:\*\*[[:space:]]+`extracting-user-stories`' "$SKILL_FILE"
}

@test "responsibility: Downstream is running-atdd-cycle (Step 4 ownership)" {
  grep -qE '\*\*Downstream:\*\*[[:space:]]+`running-atdd-cycle`' "$SKILL_FILE"
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

# --- Plan granularity -----------------------------------------------------

@test "plan granularity: SKILL.md mandates 2-5 minute grained tasks" {
  grep -qiE '2[[:space:]-]*(to[[:space:]-]*)?5[[:space:]-]*(min|minute)' "$SKILL_FILE"
}

@test "plan granularity: SKILL.md pairs each task with a verify step" {
  grep -qiE 'verif' "$SKILL_FILE"
}

# --- AT lifecycle ---------------------------------------------------------

@test "AT lifecycle: SKILL.md encodes planned -> draft -> green -> regression" {
  grep -qi 'planned' "$SKILL_FILE"
  grep -qi 'draft' "$SKILL_FILE"
  grep -qi 'green' "$SKILL_FILE"
  grep -qi 'regression' "$SKILL_FILE"
}

# --- design-doc conditionality --------------------------------------------

@test "design-doc: SKILL.md ties design-doc to trade-offs / alternatives" {
  grep -qiE 'trade.?off|alternativ' "$SKILL_FILE"
}

@test "design-doc: SKILL.md marks design-doc as conditional / optional" {
  grep -qiE 'optional|only when|conditional|not (mandatory|required)' "$SKILL_FILE"
}

# --- Output language ------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}

# --- Persona-less invariant -----------------------------------------------

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}

@test "no persona: plan template does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$PLAN_TEMPLATE"
}

@test "no persona: acceptance-tests template does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$AT_TEMPLATE"
}

# --- Template structure: plan ---------------------------------------------

@test "template: plan template has Implementation heading" {
  grep -qE '^## Implementation' "$PLAN_TEMPLATE"
}

@test "template: plan template has Testing heading" {
  grep -qE '^## Testing' "$PLAN_TEMPLATE"
}

@test "template: plan template has Finishing heading" {
  grep -qE '^## Finishing' "$PLAN_TEMPLATE"
}

@test "template: plan template pairs tasks with verify lines" {
  grep -qE 'verify:' "$PLAN_TEMPLATE"
}

# --- Template structure: acceptance-tests ---------------------------------

@test "template: acceptance-tests template has [planned] state marker" {
  grep -qF '[planned]' "$AT_TEMPLATE"
}

@test "template: acceptance-tests template has [draft] state marker" {
  grep -qF '[draft]' "$AT_TEMPLATE"
}

@test "template: acceptance-tests template has [green] state marker" {
  grep -qF '[green]' "$AT_TEMPLATE"
}

@test "template: acceptance-tests template has [regression] state marker" {
  grep -qF '[regression]' "$AT_TEMPLATE"
}
