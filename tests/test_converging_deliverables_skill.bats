#!/usr/bin/env bats
# @covers: skills/converging-deliverables/SKILL.md
# Unit Test for the converging-deliverables skill (autopilot orchestrator, #246).
# claude is NOT invoked; structural / wording invariants are checked via grep.
# LLM behavior is covered by tests/e2e/converging-deliverables.bats.
#
# Scope (#246): converging-deliverables is the autopilot MODE — a thin orchestrator
# that runs the EXISTING flow skills, narrows the human gates to two (AC approval at
# the start, merge at the end), and loops generate→review→fix until a satisfaction
# oracle (AND of green AT, reviewer verdict, zero P0/P1) holds, with safety rails.
# It does NOT permanently change the flow skills; their role changes only under autopilot.

SKILL_FILE="skills/converging-deliverables/SKILL.md"

# --- Identity -------------------------------------------------------------

@test "identity: name field matches directory (kebab-case)" {
  local name
  name=$(grep '^name:' "$SKILL_FILE" | sed 's/^name:[[:space:]]*//')
  [ "$name" = "converging-deliverables" ]
}

@test "identity: description starts with Use when (trigger-only)" {
  local desc
  desc=$(grep '^description:' "$SKILL_FILE" | sed 's/^description:[[:space:]]*//' | tr -d '"')
  [[ "$desc" == "Use when"* ]]
}

# --- Half-automated orchestration over EXISTING flow skills (F1) ----------

@test "orchestration: drives the existing flow skills in order (F1)" {
  grep -q 'extracting-user-stories' "$SKILL_FILE"
  grep -q 'writing-plan-and-tests' "$SKILL_FILE"
  grep -q 'running-atdd-cycle' "$SKILL_FILE"
  grep -q 'reviewing-deliverables' "$SKILL_FILE"
}

@test "orchestration: human gates fixed to two points — AC approval and merge (F1/AL-1)" {
  grep -qiE 'human gate|人間ゲート' "$SKILL_FILE"
  grep -qiE 'AC approval|AC 承認|defining-requirements' "$SKILL_FILE"
  grep -qiE 'merge' "$SKILL_FILE"
}

@test "non-goal: flow skills are not permanently changed (role changes only under autopilot, C1)" {
  grep -qiE 'only under autopilot|autopilot を使った場合のみ|恒久(的に)?変更しない|does not permanently change' "$SKILL_FILE"
}

# --- Satisfaction oracle (F2) ---------------------------------------------

@test "oracle: satisfaction oracle is AND of green AT, verdict, zero P0/P1 (F2)" {
  grep -qiE 'satisfaction oracle|満足オラクル' "$SKILL_FILE"
  grep -qE 'AND' "$SKILL_FILE"
  grep -qiE 'overall_correctness|verdict' "$SKILL_FILE"
  grep -qiE 'P0/P1|P0|P1' "$SKILL_FILE"
}

@test "oracle: loops generate -> review -> fix (F2)" {
  grep -qiE 'generate' "$SKILL_FILE"
  grep -qiE 'review' "$SKILL_FILE"
  grep -qiE 'fix' "$SKILL_FILE"
}

# --- Safety rails (F3) ----------------------------------------------------

@test "safety: MAX_ITERATIONS / sameness / stuck / COMPLETED_WITH_DEBT / escalation (F3/AL-5)" {
  grep -qE 'MAX_ITERATIONS' "$SKILL_FILE"
  grep -qiE 'sameness' "$SKILL_FILE"
  grep -qiE 'stuck' "$SKILL_FILE"
  grep -qE 'COMPLETED_WITH_DEBT' "$SKILL_FILE"
  grep -qiE 'escalat' "$SKILL_FILE"
}

@test "safety: reuses lib/autopilot_convergence.sh for the rails (F3)" {
  grep -q 'lib/autopilot_convergence.sh' "$SKILL_FILE"
}

@test "audit: each iteration verdict is persisted to autopilot-log.jsonl (F3/AL-4)" {
  grep -q 'autopilot-log.jsonl' "$SKILL_FILE"
}

# --- autopilot Iron Law (F4) ----------------------------------------------

@test "iron-law: references the autopilot Iron Law that overrides the standard one (F4)" {
  grep -q 'autopilot-iron-law' "$SKILL_FILE"
}

# --- Workflow mechanism ---------------------------------------------------

@test "mechanism: drives the loop through the Workflow tool (export const meta)" {
  grep -q 'Workflow' "$SKILL_FILE"
  grep -q 'export const meta' "$SKILL_FILE"
}

# --- Output language ------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}

# --- Responsibility / Integration -----------------------------------------

@test "integration: has Integration section with Upstream/Downstream" {
  grep -q '## Integration' "$SKILL_FILE"
  grep -q 'Upstream:' "$SKILL_FILE"
  grep -q 'Downstream:' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget: SKILL.md is at most 240 lines (embedded workflow script)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 240 ]
}
