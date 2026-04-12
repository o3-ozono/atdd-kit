#!/usr/bin/env bats

# Issue #155: discover の AC 承認がレビュー前に行われるため二重承認になる
# Issue #3: autopilot モード検出を --autopilot フラグ方式に移行
# Tests verify autopilot-mode conditional branching in discover and autopilot

DISCOVER="skills/discover/SKILL.md"
AUTOPILOT="commands/autopilot.md"
PLAN="skills/plan/SKILL.md"
ATDD="skills/atdd/SKILL.md"
OVERRIDES=".claude/rules/workflow-overrides.md"

# --- HARD-GATE autopilot exception ---

@test "HARD-GATE contains autopilot exception clause with --autopilot flag" {
  # HARD-GATE must mention that autopilot AC Review Round satisfies the approval requirement
  grep -q '\-\-autopilot' "$DISCOVER"
  grep -qi 'AC Review Round' "$DISCOVER"
}

@test "HARD-GATE exception requires BOTH --autopilot AND AC Review Round approval" {
  # Must not read as "autopilot means no approval needed" -- both conditions required
  local hard_gate
  hard_gate=$(sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER")
  echo "$hard_gate" | grep -q '\-\-autopilot'
  echo "$hard_gate" | grep -qi 'AC Review Round'
}

# --- AC1: autopilot mode skips Step 7 approval gate and Step 8 ---

@test "AC1: Step 7 has autopilot-mode conditional branch" {
  # Step 7 must contain conditional logic for --autopilot flag
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi '\-\-autopilot\|autopilot'
}

@test "AC1: Step 7 autopilot mode outputs draft AC without approval request" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'draft'
}

@test "AC1: Step 7 autopilot mode skips approval request" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'skip'
}

@test "AC1: Step 8 has autopilot skip instruction" {
  local step8
  step8=$(sed -n '/### Step 8/,/^---$/p' "$DISCOVER")
  echo "$step8" | grep -qi 'skip\|autopilot'
}

# --- AC2: standalone mode preserves approval gate ---

@test "AC2: Step 7 standalone mode preserves approval request text" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'Approve.*Needs revision\|approve'
}

@test "AC2: Step 8 standalone mode preserves Issue comment posting" {
  local step8
  step8=$(sed -n '/### Step 8/,/^---$/p' "$DISCOVER")
  echo "$step8" | grep -q 'gh issue comment'
}

@test "AC2: Step 8 standalone mode preserves inline plan execution" {
  local step8
  step8=$(sed -n '/### Step 8/,/^---$/p' "$DISCOVER")
  echo "$step8" | grep -qi 'inline.*plan\|plan.*inline\|plan.*Core.*Flow'
}

# --- autopilot Issue comment posting after AC Review Round ---

@test "autopilot AC Review Round posts Issue comment after user approval" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -q 'gh issue comment'
}

@test "autopilot Issue comment is posted AFTER approval, not before" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  # "approval" or "approve" must appear before "gh issue comment" in the section
  local approval_line comment_line
  approval_line=$(echo "$acr" | grep -ni 'approv' | head -1 | cut -d: -f1)
  comment_line=$(echo "$acr" | grep -ni 'gh issue comment' | head -1 | cut -d: -f1)
  [[ -n "$approval_line" ]]
  [[ -n "$comment_line" ]]
  [[ "$approval_line" -lt "$comment_line" ]]
}

# --- Three Amigos unified approval flow ---

@test "autopilot AC Review Round mentions Three Amigos integration" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -qi 'Three Amigos'
}

@test "autopilot AC Review Round has reject handling" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -qi 'reject'
}

@test "reject triggers PO modification, not AC Review Round restart" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -qi 'PO.*修正\|PO.*modif\|PO.*revise\|PO.*correct'
}

# --- Cross-file consistency ---

@test "discover HARD-GATE and autopilot AC Review Round are consistent on approval flow" {
  # Both files must reference the autopilot approval delegation
  grep -qi 'AC Review Round' "$DISCOVER"
  grep -qi 'approval' "$AUTOPILOT"
}

@test "discover autopilot exception is documented in HARD-GATE, not just Step 7" {
  local hard_gate
  hard_gate=$(sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER")
  echo "$hard_gate" | grep -qi 'autopilot\|AC Review Round'
}

# --- AC3+AC4: AUTOPILOT-GUARD uses --autopilot flag in all 3 skills ---

@test "AC3: plan AUTOPILOT-GUARD uses --autopilot flag for detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN")
  echo "$guard" | grep -q '\-\-autopilot'
}

@test "AC4: atdd AUTOPILOT-GUARD uses --autopilot flag for detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$ATDD")
  echo "$guard" | grep -q '\-\-autopilot'
}

@test "AC1: discover AUTOPILOT-GUARD uses --autopilot flag for detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER")
  echo "$guard" | grep -q '\-\-autopilot'
}

# --- AC5: autopilot.md passes --autopilot flag in Skill calls ---

@test "AC5: autopilot Phase 1 passes --autopilot in discover Skill call" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -q '\-\-autopilot'
}

@test "AC5: autopilot Phase 3 passes --autopilot in atdd Skill call" {
  local phase3
  phase3=$(sed -n '/## Phase 3/,/## Phase 4/p' "$AUTOPILOT")
  echo "$phase3" | grep -q '\-\-autopilot'
}

# --- Negative tests: no teammate-message residue in AUTOPILOT-GUARDs ---

@test "No teammate-message references remain in discover AUTOPILOT-GUARD" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER")
  ! echo "$guard" | grep -qi 'teammate-message'
}

@test "No teammate-message references remain in plan AUTOPILOT-GUARD" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN")
  ! echo "$guard" | grep -qi 'teammate-message'
}

@test "No teammate-message references remain in atdd AUTOPILOT-GUARD" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$ATDD")
  ! echo "$guard" | grep -qi 'teammate-message'
}
