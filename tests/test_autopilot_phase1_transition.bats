#!/usr/bin/env bats
# @covers: commands/autopilot.md
# Issue #101: discover COMPLETE 後の AC Review Round 即時遷移が再発停止する (#83 リグレッション)
# Tests verify:
#   AC1: discover autopilot terminal output is skill-status only
#   AC2: autopilot Phase 1 completion requires Agent tool calls
#   AC3: Regression -- discover COMPLETE triggers immediate AC Review Round transition

DISCOVER="skills/discover/SKILL.md"
AUTOPILOT="commands/autopilot.md"

# ===================================================================
# AC1: discover autopilot terminal output is skill-status only
# ===================================================================

@test "AC1: Step 7 autopilot mode outputs skill-status block only" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  # Must say "only" output is skill-status block in autopilot mode
  echo "$step7" | grep -qi 'only.*output\|output.*only\|skill-status.*only\|only.*skill-status'
}

@test "AC1: Step 7 autopilot mode explicitly excludes draft AC listings from output" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'Do NOT include.*draft\|draft.*not.*output\|exclude.*draft\|no.*draft'
}

@test "AC1: Step 7 autopilot mode excludes UX check results from output" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'UX check\|ux.*result\|not.*ux\|exclude.*ux'
}

@test "AC1: Step 7 autopilot mode excludes Interruption check results from output" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'Interruption check\|interruption.*result\|not.*interruption\|exclude.*interruption'
}

@test "AC1: Step 7 autopilot mode excludes Discussion Summary from output" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'Discussion Summary\|discussion.*summary\|not.*discussion\|exclude.*discussion'
}

@test "AC1: Bug Flow Present Deliverables has independent autopilot mode instruction (not implicit reference)" {
  # Issue #108: bug flow に Persona Selection が追加され Step 番号が +1 シフト
  # Present Deliverables は現在 Step 6 (元 Step 5)
  local step
  step=$(sed -n '/### Step 6: Present Deliverables/,/### Step 7/p' "$DISCOVER")
  # Must NOT rely solely on "same as Step 7" -- must have explicit autopilot branch
  echo "$step" | grep -qi '\-\-autopilot\|autopilot mode'
}

@test "AC1: Bug Flow Present Deliverables autopilot mode outputs skill-status only" {
  local step
  step=$(sed -n '/### Step 6: Present Deliverables/,/### Step 7/p' "$DISCOVER")
  echo "$step" | grep -qi 'skill-status\|SKILL_STATUS'
}

@test "AC1: Bug Flow Present Deliverables has explicit standalone mode branch" {
  local step
  step=$(sed -n '/### Step 6: Present Deliverables/,/### Step 7/p' "$DISCOVER")
  echo "$step" | grep -qi 'standalone'
}

# ===================================================================
# AC2: autopilot Phase 1 completion requires Agent tool calls
# ===================================================================

@test "AC2: Phase 1 definition states AC Review Round agents must be spawned before Phase 1 is complete" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -qi 'not complete\|incomplete\|not.*complet\|Phase 1.*complete.*AC Review\|AC Review.*complet'
}

@test "AC2: Phase 1 states receiving SKILL_STATUS COMPLETE alone does not complete Phase 1" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -qi 'alone.*not\|not.*alone\|COMPLETE.*alone\|alone.*complete'
}

@test "AC2: Phase 1 instructs to issue Agent tool calls before any user-facing text" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -qi 'Agent tool\|spawn.*agent\|agent.*spawn\|immediately.*agent\|agent.*immediately'
}

# ===================================================================
# AC3: Regression -- discover COMPLETE triggers immediate AC Review Round
# ===================================================================

@test "AC3: Phase 1 prohibits presenting draft deliverables to user" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -qi 'Do NOT.*draft\|not.*present.*draft\|draft.*not.*present'
}

@test "AC3: Phase 1 prohibits intermediate user-facing messages before Agent tool calls" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -qi 'Do NOT.*intermediate\|no.*intermediate\|intermediate.*message.*not'
}

@test "AC3: Phase 1 requires Agent tool calls in the same response as COMPLETE" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -qi 'same.*response\|same.*turn\|immediately.*agent\|agent.*immediately'
}

# ===================================================================
# AC1 (Issue #162): NEXT_REQUIRED_ACTION dispatch metadata
# ===================================================================

@test "AC1(#162): autopilot Status Evaluation defines Supplementary Dispatch table for NEXT_REQUIRED_ACTION" {
  grep -q 'Supplementary Dispatch' "$AUTOPILOT"
}

@test "AC1(#162): autopilot Supplementary Dispatch lists spawn_ac_review_agents" {
  grep -q 'spawn_ac_review_agents' "$AUTOPILOT"
}

@test "AC1(#162): autopilot Phase 1 references NEXT_REQUIRED_ACTION dispatch" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -q 'NEXT_REQUIRED_ACTION'
}

@test "AC1(#162): autopilot Extraction Rule parses NEXT_REQUIRED_ACTION" {
  local extr
  extr=$(sed -n '/### Extraction Rule/,/### Action Matrix/p' "$AUTOPILOT")
  echo "$extr" | grep -q 'NEXT_REQUIRED_ACTION'
}

@test "AC1(#162): discover Step 7 autopilot mode emits NEXT_REQUIRED_ACTION with spawn_ac_review_agents" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -q 'NEXT_REQUIRED_ACTION' \
    && echo "$step7" | grep -q 'spawn_ac_review_agents'
}

@test "AC1(#162): discover Bug Flow Step 6 autopilot mode emits NEXT_REQUIRED_ACTION" {
  local step
  step=$(sed -n '/### Step 6: Present Deliverables/,/### Step 7/p' "$DISCOVER")
  echo "$step" | grep -q 'NEXT_REQUIRED_ACTION' \
    && echo "$step" | grep -q 'spawn_ac_review_agents'
}

@test "AC1(#162): discover Step 7 standalone branch does not emit NEXT_REQUIRED_ACTION" {
  # Lines between "**Standalone mode:**" and the next blank-section boundary
  local standalone
  standalone=$(sed -n '/\*\*Standalone mode/,/### Step 8/p' "$DISCOVER")
  ! echo "$standalone" | grep -q 'NEXT_REQUIRED_ACTION'
}
