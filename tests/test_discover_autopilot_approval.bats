#!/usr/bin/env bats

# Issue #155: discover の AC 承認がレビュー前に行われるため二重承認になる
# Tests verify autopilot-mode conditional branching in discover and autopilot

DISCOVER="skills/discover/SKILL.md"
AUTOPILOT="commands/autopilot.md"
OVERRIDES=".claude/rules/workflow-overrides.md"

# --- AC5: HARD-GATE autopilot exception ---

@test "AC5: HARD-GATE contains autopilot exception clause" {
  # HARD-GATE must mention that autopilot AC Review Round satisfies the approval requirement
  grep -q 'teammate-message' "$DISCOVER"
  grep -qi 'AC Review Round' "$DISCOVER"
}

@test "AC5: HARD-GATE exception requires BOTH teammate-message AND AC Review Round approval" {
  # Must not read as "autopilot means no approval needed" -- both conditions required
  local hard_gate
  hard_gate=$(sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER")
  echo "$hard_gate" | grep -qi 'teammate-message'
  echo "$hard_gate" | grep -qi 'AC Review Round'
}

# --- AC1: autopilot mode skips Step 7 approval gate and Step 8 ---

@test "AC1: Step 7 has autopilot-mode conditional branch" {
  # Step 7 must contain conditional logic for autopilot context
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'teammate-message\|autopilot'
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

# --- AC4: autopilot Issue comment posting after AC Review Round ---

@test "AC4: autopilot AC Review Round posts Issue comment after user approval" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -q 'gh issue comment'
}

@test "AC4: autopilot Issue comment is posted AFTER approval, not before" {
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

# --- AC3: Three Amigos unified approval flow ---

@test "AC3: autopilot AC Review Round mentions Three Amigos integration" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -qi 'Three Amigos'
}

@test "AC3: autopilot AC Review Round has reject handling" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -qi 'reject'
}

@test "AC3: reject triggers PO modification, not AC Review Round restart" {
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
