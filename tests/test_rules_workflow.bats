#!/usr/bin/env bats
# @covers: rules/atdd-kit.md CLAUDE.md
# AC reference: https://github.com/o3-ozono/atdd-kit/issues/187

setup() {
  RULES_FILE="rules/atdd-kit.md"
  CLAUDE_FILE="CLAUDE.md"
  STEP_NAMES=(
    "Discovery & Definition"
    "User Stories"
    "Plan"
    "ATDD"
    "Review"
    "Merge"
  )
  V1_SKILLS=(
    defining-requirements
    extracting-user-stories
    writing-plan-and-tests
    running-atdd-cycle
    reviewing-deliverables
    merging-and-deploying
  )
}

# --- AC1: rules/atdd-kit.md describes the new 6-step flow ---

@test "AC1: rules/atdd-kit.md contains all 6 step names" {
  for step in "${STEP_NAMES[@]}"; do
    grep -F "$step" "$RULES_FILE"
  done
}

@test "AC1: rules/atdd-kit.md contains all 6 v1 skill names" {
  for skill in "${V1_SKILLS[@]}"; do
    grep -F "$skill" "$RULES_FILE"
  done
}

@test "AC1: rules/atdd-kit.md is 60 lines or fewer" {
  local lines
  lines=$(wc -l < "$RULES_FILE")
  [[ "$lines" -le 60 ]]
}

# --- AC2: CLAUDE.md describes the new flow with docs/issues/ reference ---

@test "AC2: CLAUDE.md mentions Discovery & Definition" {
  grep -F "Discovery & Definition" "$CLAUDE_FILE"
}

@test "AC2: CLAUDE.md mentions Merge" {
  grep -F "Merge" "$CLAUDE_FILE"
}

@test "AC2: CLAUDE.md references docs/issues/" {
  grep -F "docs/issues/" "$CLAUDE_FILE"
}

@test "AC2: CLAUDE.md preserves DEVELOPMENT.md and CHANGELOG.md references" {
  grep -F "DEVELOPMENT.md" "$CLAUDE_FILE"
  grep -F "CHANGELOG.md" "$CLAUDE_FILE"
}

# --- AC3: autopilot mentions are fully removed (case-insensitive regression guard) ---

@test "AC3: no autopilot mentions in rules/ or CLAUDE.md (case-insensitive)" {
  ! grep -rni "autopilot" rules/ "$CLAUDE_FILE"
}

# --- AC4: 1 Issue = 1 worktree = 1 Draft PR discipline is stated verbatim ---

@test "AC4: rules/atdd-kit.md states 1 Issue = 1 worktree = 1 Draft PR" {
  grep -F "1 Issue = 1 worktree = 1 Draft PR" "$RULES_FILE"
}

# --- AC5: "Open Draft PR on first commit/push" principle is documented ---

@test "AC5: rules/atdd-kit.md mentions Draft PR" {
  grep -E "Draft PR" "$RULES_FILE"
}

@test "AC5: rules/atdd-kit.md describes opening Draft PR on first/initial commit/push" {
  grep -E "(first|initial).*(commit|push)|(commit|push).*(first|initial)" "$RULES_FILE"
}
