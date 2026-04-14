#!/usr/bin/env bats

# Tests for Issue #58: autopilot SKILL_STATUS transition logic (AC5, AC6, AC7)

AUTOPILOT="commands/autopilot.md"

# Helper: extract Status Evaluation section content
get_evaluation_section() {
  sed -n '/^## Status Evaluation/,/^## /p' "$AUTOPILOT"
}

# ===================================================================
# AC5: autopilot uses SKILL_STATUS for phase transition decisions
# ===================================================================

@test "AC5: autopilot has Status Evaluation section" {
  grep -q '## Status Evaluation' "$AUTOPILOT"
}

@test "AC5: Status Evaluation section references skill-status block" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'skill-status'
}

@test "AC5: Status Evaluation instructs to locate last block" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'last\|final'
}

@test "AC5: RECOMMENDATION is informational only — not used for branching" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'recommendation.*informational\|not.*branch\|do not.*branch\|informational only'
}

# ===================================================================
# AC6: Autopilot action matrix covers all statuses
# ===================================================================

@test "AC6: action matrix covers COMPLETE -> proceed" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'complete.*proceed\|proceed.*complete'
}

@test "AC6: action matrix covers PENDING -> wait" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'pending.*wait\|wait.*pending'
}

@test "AC6: action matrix covers BLOCKED -> stop and report" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'blocked.*stop\|stop.*blocked'
}

@test "AC6: action matrix covers FAILED -> stop autopilot" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'failed.*stop\|stop.*failed'
}

@test "AC6: unknown/invalid value treated as PENDING" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'other.*pending\|unknown.*pending\|invalid.*pending\|any other.*pending'
}

# ===================================================================
# AC7: Fallback when no SKILL_STATUS block found
# ===================================================================

@test "AC7: Status Evaluation has fallback rule for missing block" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'fallback\|no.*block\|missing.*block\|block.*not.*found\|absent'
}

@test "AC7: fallback instructs to STOP (not advance)" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'stop.*advance\|do not.*advance\|stop\b'
}

@test "AC7: fallback instructs to post warning comment" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'warning\|post.*comment\|issue comment'
}

@test "AC7: fallback prohibits text heuristics" {
  get_evaluation_section "$AUTOPILOT" | grep -qi 'do not.*infer\|not.*infer\|do not.*text\|text.*heuristic\|authoritative'
}

# ===================================================================
# AC5: Status Evaluation positioned after Output Channels
# ===================================================================

@test "AC5: Status Evaluation appears after Output Channels section" {
  local output_channels_line
  output_channels_line=$(grep -n '## Output Channels' "$AUTOPILOT" | head -1 | cut -d: -f1)
  local evaluation_line
  evaluation_line=$(grep -n '## Status Evaluation' "$AUTOPILOT" | head -1 | cut -d: -f1)
  [ "$evaluation_line" -gt "$output_channels_line" ]
}
