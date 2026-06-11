#!/usr/bin/env bats
# @covers: agents/**
# Issue #259: phase model assignment — agents/README.md model policy pins.
# claude is NOT invoked; structural / wording invariants are checked via grep.
#
# Scope: the "Model and effort are intentionally unset" policy is replaced by
# the bench-backed phase policy — impl / review subagents default to Sonnet
# (specified in the reviewing-deliverables Workflow script's agent() options,
# never in agents/*.md frontmatter — the #105 session-inheritance design stays),
# the design phase and the orchestrator keep the session model, and a one-way
# escalation path covers convergence-failure halts.

README="agents/README.md"
AUTOPILOT="skills/autopilot/SKILL.md"

# --- AT-004 (a): the old blanket policy is gone -----------------------------

@test "policy (#259): 'intentionally unset' is replaced by the phase policy (AT-004)" {
  ! grep -q 'intentionally unset' "$README"
}

# --- AT-004 (b): the new Sonnet policy and escalation path exist ------------

@test "policy (#259): impl / review subagents = Sonnet, set in the Workflow script, not frontmatter (AT-004)" {
  grep -qi 'sonnet' "$README"
  grep -qE 'reviewing-deliverables' "$README"
  grep -qi 'frontmatter' "$README"
  grep -qE '#105' "$README"
}

@test "policy (#259): escalation path — convergence-failure halt promotes to the session model, one-way per Issue (AT-004/AT-005)" {
  grep -qiE 'escalation' "$README"
  grep -qF 'convergence-failure halt (`MAX_ITERATIONS` / `sameness-detector` / `stuck`)' "$README"
  grep -qiE 'one-way per Issue' "$README"
}

@test "policy (#259): the escalation trigger definition is literally IDENTICAL in agents/README.md and autopilot SKILL.md (AT-005)" {
  local phrase='convergence-failure halt (`MAX_ITERATIONS` / `sameness-detector` / `stuck`)'
  grep -qF "$phrase" "$README"
  grep -qF "$phrase" "$AUTOPILOT"
}

# --- AT-004 (c): the bench summary is recorded ------------------------------

@test "bench (#259): cost ratio and bench conditions are recorded (AT-004/CS-1)" {
  grep -qF 'Sonnet 1.0 : Opus 2.2 : Fable 4.1' "$README"
  # bench conditions: 2 Issues x 3 models x 10 runs, 2026-06-10〜11
  grep -qE '2 Issues? ×|2 Issue ×' "$README"
  grep -qE '10 runs?' "$README"
  grep -qE '2026-06-1' "$README"
  # design-judgment consistency basis for keeping the design phase on the session model
  grep -qF '20/20' "$README"
}

# --- AT-004 (d): design phase / orchestrator exclusion ----------------------

@test "scope (#259): design phase and orchestrator stay on the session model (AT-004/CS-3)" {
  grep -qiE 'design phase' "$README"
  grep -qiE 'orchestrator' "$README"
  grep -qi 'session' "$README"
}

# --- #105 regression: effort stays unset, no Model/Effort table columns -----

@test "regression (#259): effort stays unset (session inheritance) and the Agent table gains no Model/Effort columns (#105 AC3)" {
  grep -qiE 'effort.*(unset|session|inherit)' "$README"
  ! grep -q '| Model |' "$README"
  ! grep -q '| Effort |' "$README"
}
