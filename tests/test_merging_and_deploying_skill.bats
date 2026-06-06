#!/usr/bin/env bats
# @covers: skills/merging-and-deploying/SKILL.md
# Unit Test for the merging-and-deploying skill (#193 / #179 Step B6).
# Per `docs/testing-skills.md` (#222), this is a Unit Test — `claude` is not
# invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/merging-and-deploying.bats`.
#
# Scope (per #193 AC): assert the merge -> deploy -> post-deploy regression
# mechanism plus the standard responsibility / budget / language gates.
#   - merge -> deploy flow
#   - post-deploy AT re-run (regression against tests/acceptance/)
#   - flow terminus (Step 6 of 6) — no downstream skill

SKILL_FILE="skills/merging-and-deploying/SKILL.md"

# --- Merge -> deploy flow -------------------------------------------------

@test "flow: SKILL.md performs a PR merge" {
  grep -qiE 'merge' "$SKILL_FILE"
}

@test "flow: SKILL.md performs a deploy step" {
  grep -qiE 'deploy' "$SKILL_FILE"
}

# --- Post-deploy regression -----------------------------------------------

@test "regression: SKILL.md re-runs Acceptance Tests post-deploy" {
  grep -qiE 'post-deploy' "$SKILL_FILE"
  grep -qiE 're-?run|re-?execut' "$SKILL_FILE"
}

@test "regression: SKILL.md re-runs tests from tests/acceptance/" {
  grep -q 'tests/acceptance/' "$SKILL_FILE"
}

@test "regression: SKILL.md frames the post-deploy AT run as regression" {
  grep -qiE 'regression' "$SKILL_FILE"
}

# --- Merge precondition ---------------------------------------------------

@test "precondition: SKILL.md requires a passing review before merge" {
  grep -qiE 'review|PASS' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget: SKILL.md is at most 200 lines (#216 PRD design rule)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 200 ]
}

# --- Responsibility boundary ----------------------------------------------

@test "responsibility: Upstream is reviewing-deliverables" {
  grep -qE '\*\*Upstream:\*\*[[:space:]]+`reviewing-deliverables`' "$SKILL_FILE"
}

@test "responsibility: SKILL.md has a Downstream line (flow terminus)" {
  grep -qE '\*\*Downstream:\*\*' "$SKILL_FILE"
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
