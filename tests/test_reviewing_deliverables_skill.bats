#!/usr/bin/env bats
# @covers: skills/reviewing-deliverables/SKILL.md
# Unit Test for the reviewing-deliverables skill (#234 / #179 Step B5).
# Per `docs/testing-skills.md` (#222), this is a Unit Test — `claude` is not
# invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/reviewing-deliverables.bats`.
#
# Scope (per #234): the skill replaces the former fixed 6-subagent SERIAL roster
# with a Workflow-tool review that (a) generates the reviewer panel DYNAMICALLY
# from the deliverable content, (b) reviews in PARALLEL, (c) verifies findings
# across multiple ADVERSARIAL rounds, and (d) covers functional + non-functional
# (security / performance / usability) + clean-code / testability + positive
# (advocate) / negative (skeptic) stances. Standard responsibility / language /
# budget gates are retained. The serial constraint is dissolved because the
# Workflow tool isolates each agent() context (#216 PRD OQ#1 was deferred here).

SKILL_FILE="skills/reviewing-deliverables/SKILL.md"

# --- Workflow-based mechanism ---------------------------------------------

@test "mechanism: SKILL.md drives the review through the Workflow tool" {
  grep -q 'Workflow' "$SKILL_FILE"
}

@test "mechanism: SKILL.md embeds a runnable workflow script (export const meta)" {
  grep -q 'export const meta' "$SKILL_FILE"
}

@test "mechanism: the workflow has the five phases Scout/Generate/Review/Verify/Aggregate" {
  grep -q 'Scout' "$SKILL_FILE"
  grep -q 'Generate' "$SKILL_FILE"
  grep -q 'Review' "$SKILL_FILE"
  grep -q 'Verify' "$SKILL_FILE"
  grep -q 'Aggregate' "$SKILL_FILE"
}

# --- Dynamic reviewer generation ------------------------------------------

@test "dynamic: reviewers are generated dynamically from the deliverable, not a fixed roster" {
  grep -qiE 'dynamic' "$SKILL_FILE"
  grep -qiE 'scout' "$SKILL_FILE"
  # the panel scales with the change rather than enumerating a fixed list
  grep -qiE 'scale|derive|generate the reviewer panel|panel' "$SKILL_FILE"
}

# --- Parallel execution (replaces serial) ---------------------------------

@test "execution: SKILL.md runs the reviewers in parallel" {
  grep -qiE 'parallel|pipeline' "$SKILL_FILE"
}

# --- Multi-round adversarial verification ---------------------------------

@test "verify: findings are challenged across multiple adversarial rounds" {
  grep -qiE 'adversarial' "$SKILL_FILE"
  grep -qiE 'round|majority|refute|challenge' "$SKILL_FILE"
}

# --- Multi-perspective coverage (functional + non-functional + stances) ----

@test "coverage: non-functional lenses (security / performance / usability)" {
  grep -qiE 'security' "$SKILL_FILE"
  grep -qiE 'performance' "$SKILL_FILE"
  grep -qiE 'usability' "$SKILL_FILE"
}

@test "coverage: clean-code and testability lenses" {
  grep -qiE 'clean-code|clean code|cleanliness' "$SKILL_FILE"
  grep -qiE 'testability' "$SKILL_FILE"
}

@test "coverage: documentation lens is an ALWAYS-include lens (#241)" {
  grep -qiE 'documentation' "$SKILL_FILE"
  # the ALWAYS-include list in the Generate prompt names documentation
  grep -qE 'ALWAYS include these lenses:.*documentation' "$SKILL_FILE"
}

@test "coverage: documentation lens checks accuracy, consistency, and follow-through/sync (#241)" {
  grep -qiE 'accuracy' "$SKILL_FILE"
  grep -qiE 'consistency' "$SKILL_FILE"
  grep -qiE 'follow-through|sync' "$SKILL_FILE"
  # the DEVELOPMENT.md README/CHANGELOG/version follow-through invariant
  grep -qE 'README' "$SKILL_FILE"
  grep -qiE 'CHANGELOG' "$SKILL_FILE"
  grep -qE 'plugin\.json' "$SKILL_FILE"
}

@test "coverage: positive (advocate) and negative (skeptic) stances" {
  grep -qiE 'advocate' "$SKILL_FILE"
  grep -qiE 'skeptic' "$SKILL_FILE"
}

# --- Verification via AT ---------------------------------------------------

@test "verification: SKILL.md states runtime behavior is verified by Acceptance Tests" {
  grep -qiE 'acceptance test' "$SKILL_FILE"
}

@test "verification: SKILL.md does not mandate manual / preview verification" {
  grep -qiE 'manual' "$SKILL_FILE"
  grep -qiE 'not (require|mandat|force)|no manual|without manual|not mandatory' "$SKILL_FILE"
}

# --- Single PASS/FAIL verdict ---------------------------------------------

@test "output: the Aggregate phase produces a single PASS / FAIL verdict" {
  grep -qE 'PASS' "$SKILL_FILE"
  grep -qE 'FAIL' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget: SKILL.md is at most 240 lines (raised for the embedded workflow script)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 240 ]
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

# --- Persona-less invariant (User Story form, unrelated to reviewer personas)

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}
