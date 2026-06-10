#!/usr/bin/env bats
# @covers: skills/autopilot/SKILL.md
# Unit Test for the autopilot skill (autopilot orchestrator, #246).
# claude is NOT invoked; structural / wording invariants are checked via grep.
# LLM behavior is covered by tests/e2e/autopilot.bats.
#
# Scope (#246, gates re-placed in #249): autopilot is the autopilot MODE — a thin
# orchestrator that runs the EXISTING flow skills, narrows the human gates to three
# (requirements approval at the start, design approval before ATDD, merge at the
# end), and loops generate→review→fix until a satisfaction oracle (AND of green AT,
# reviewer verdict, zero P0/P1) holds, with safety rails.
# It does NOT permanently change the flow skills; their role changes only under autopilot.

SKILL_FILE="skills/autopilot/SKILL.md"

# --- Identity -------------------------------------------------------------

@test "identity: name field matches directory (kebab-case)" {
  local name
  name=$(grep '^name:' "$SKILL_FILE" | sed 's/^name:[[:space:]]*//')
  [ "$name" = "autopilot" ]
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

@test "orchestration: human gates fixed to three points — requirements, design approval, merge (F1/AL-1, #249)" {
  grep -qiE 'human gate|人間ゲート' "$SKILL_FILE"
  grep -qiE 'requirements approval|defining-requirements' "$SKILL_FILE"
  grep -qiE 'design approval|design-approval' "$SKILL_FILE"
  grep -qiE 'merge' "$SKILL_FILE"
  grep -qiE 'exactly three' "$SKILL_FILE"
  # the old two-gate contract must be gone
  ! grep -qiE 'exactly two|two gates only' "$SKILL_FILE"
}

@test "gates (#249): ATDD never starts before the design-approval gate" {
  # the user-expected flow: 壁打ち → design review → approval → ATDD
  grep -qiE 'ATDD never starts before (this|the design-approval) gate' "$SKILL_FILE"
  # design phase loops only the design steps; running-atdd-cycle is impl-only
  grep -qE "\['extracting-user-stories', 'writing-plan-and-tests'\]" "$SKILL_FILE"
  grep -qE "\['running-atdd-cycle'\]" "$SKILL_FILE"
  # fail-closed: looping the AT step inside the design phase must throw
  grep -qE "PHASE === 'design' && STEPS\.includes\(AT_STEP\)" "$SKILL_FILE"
}

@test "gates (#249): design-gate rejection comments re-enter the design loop as findings" {
  grep -qiE 'evidence_ref.*human comment|human comment.*evidence_ref' "$SKILL_FILE"
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

# --- Code-deep oracle (#246 review: rails/oracle must be code, not just prose)

@test "oracle: AT-green is DETERMINISTIC (test exit code), not an LLM opinion (AL-3)" {
  grep -qiE 'deterministic AT gate' "$SKILL_FILE"
  grep -qiE 'exit code' "$SKILL_FILE"
  grep -qE 'AL-3' "$SKILL_FILE"
  # the inert "!verdict.atRequired || verdict.atGreen" leg (always-true) must be gone
  ! grep -qE '!verdict\.atRequired' "$SKILL_FILE"
}

@test "oracle: AC→AT coverage gate is wired and run in a separate context (AL-2)" {
  grep -qiE 'coverage gate' "$SKILL_FILE"
  grep -qiE 'separate from the AT author' "$SKILL_FILE"
  grep -qE 'AL-2' "$SKILL_FILE"
}

@test "oracle: fail-safe — confirmed P0/P1 blocks regardless of evidence_ref" {
  grep -qiE 'fail-safe' "$SKILL_FILE"
  grep -qE 'priorityOf' "$SKILL_FILE"
  # the old fail-OPEN filter (required evidence_ref to even count as blocking) must be gone
  ! grep -qE 'f\.evidence_ref && f\.priority' "$SKILL_FILE"
}

@test "oracle: consumer schema requires priority + evidence_ref in findings items" {
  grep -qE "required: \['priority', 'evidence_ref'\]" "$SKILL_FILE"
}

@test "rails: a non-zero record_iteration (corrupt/empty fingerprint) is itself a halt" {
  grep -qiE 'record-error' "$SKILL_FILE"
}

# --- round-2 hardening regression guards (#246 second review) -------------

@test "audit: the log path uses the slug-suffixed issue dir, not the bare number" {
  # regression guard for the round-2 blocker: docs/issues/<NNN>/ would write to a
  # phantom dir and break AL-4. It must resolve docs/issues/<NNN>-*/ like the gate.
  grep -qE 'docs/issues/\$\{NNN\}-\*' "$SKILL_FILE"
  ! grep -qE 'docs/issues/\$\{NNN\}/autopilot-log' "$SKILL_FILE"
}

@test "config: AT_STEP must be one of STEPS (fail-closed, gates can't silently vanish)" {
  grep -qE 'STEPS\.includes\(AT_STEP\)' "$SKILL_FILE"
}

@test "rails: the halt is computed in JS from raw exit codes, not summarized by the LLM" {
  grep -qE 'maxIterExit|samenessExit|stuckExit' "$SKILL_FILE"
  grep -qE "halt = .*MAX_ITERATIONS" "$SKILL_FILE"
}

@test "audit: record_iteration is invoked with its full 5-arg signature" {
  # the rails prompt must pass <jsonl> <it> <step> <verdict> <fp>, not 2 args
  grep -qE 'record_iteration "<resolved-log-path>" \$\{it\} \$\{step\}' "$SKILL_FILE"
}

@test "AL-2: the approved anchor is pinned at phase start and drift halts the loop (enforced freeze)" {
  grep -qE 'pin_anchor' "$SKILL_FILE"
  grep -qE 'check_pin' "$SKILL_FILE"
  grep -qiE 'ac-drift' "$SKILL_FILE"
  # the impl freeze pins the human-approved source (prd + user-stories), not the loop-mutable AT
  grep -qE 'prd\.md .*user-stories\.md' "$SKILL_FILE"
}

@test "AL-2 (#249): one pin per phase — design anchors to PRD, impl to the design-gate-approved set" {
  # design phase pin: prd.md only (the loop edits user-stories.md, so pinning it
  # there would guarantee a false ac-drift halt — the #249 contradiction)
  grep -qE 'autopilot-prd\.pin' "$SKILL_FILE"
  grep -qE 'autopilot-design\.pin' "$SKILL_FILE"
  # a pin must never cover an artifact the same phase's loop may edit
  grep -qiE 'never an artifact (this|the same) phase' "$SKILL_FILE"
  # acceptance-tests.md is NOT pinned (lifecycle markers move); coverage gate guards it
  grep -qiE 'acceptance-tests\.md is NOT pinned' "$SKILL_FILE"
  # the single-pin two-gate freeze must be gone
  ! grep -qE 'autopilot-ac\.pin' "$SKILL_FILE"
}
