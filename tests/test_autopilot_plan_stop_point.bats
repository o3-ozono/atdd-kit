#!/usr/bin/env bats

# Tests for Issue #54: autopilot Plan approval clear/continue stop-point

AUTOPILOT_CMD="commands/autopilot.md"
PO_AGENT="agents/po.md"

# AC1: Stop-point fires after Plan Review Round step 5 in the same session
@test "AC1: Plan Review Round has step 6 after ready-to-go label assignment" {
  # step 5 assigns ready-to-go, step 6 must follow in the same section
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  echo "$plan_review" | grep -q 'ready-to-go'
  echo "$plan_review" | grep -qE 'step 6|Step 6|6\.'
}

@test "AC1: Stop-point presents clear/continue choices" {
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  echo "$plan_review" | grep -qi 'clear'
  echo "$plan_review" | grep -qi 'continue'
}

@test "AC1: Stop-point uses AskUserQuestion or plain-text fallback" {
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  echo "$plan_review" | grep -qiE 'AskUserQuestion|plain.text'
}

# AC2: clear selection shows resume guidance and terminates autopilot
@test "AC2: clear option shows resume guidance with autopilot command" {
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  echo "$plan_review" | grep -qE '/atdd-kit:autopilot'
}

@test "AC2: clear option terminates autopilot (STOP or terminate)" {
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  echo "$plan_review" | grep -qiE 'stop|terminat|end'
}

# AC3: continue proceeds to Phase 3 without additional steps
@test "AC3: continue option proceeds to Phase 3" {
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  echo "$plan_review" | grep -qi 'Phase 3'
}

# AC4: mid-phase resume (new session with ready-to-go) skips stop-point
@test "AC4: stop-point condition states it only fires in current session" {
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  echo "$plan_review" | grep -qiE 'current session|same session|mid-phase resume'
}

# AC5: revision loop re-fires stop-point (implied by: stop-point fires every time Plan Review Round runs)
@test "AC5: Plan Review Round step 6 fires every time (no once-only guard)" {
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  # The condition must NOT say "only once" or "first time" -- it fires every time
  ! echo "$plan_review" | grep -qiE 'only once|first time only'
}

# AC6: Other/unclassifiable response triggers STOP
@test "AC6: unclassifiable response follows Autonomy Rules failure mode" {
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  echo "$plan_review" | grep -qiE 'other|unclassif|cannot be classified|could not be classified'
}

@test "AC6: unclassifiable response results in STOP" {
  plan_review=$(sed -n '/## Plan Review Round/,/## Phase 3/p' "$AUTOPILOT_CMD")
  # The Other/fallback path must STOP
  echo "$plan_review" | grep -qiE 'stop'
}

# agents/po.md: AskUserQuestion in tools list
@test "po.md has AskUserQuestion in tools list" {
  grep -q 'AskUserQuestion' "$PO_AGENT"
}
