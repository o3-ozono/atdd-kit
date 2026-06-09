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

# --- AC3 (#246 supersedes #187): autopilot is revived as a GOVERNED mode ---
# #187 fully removed the legacy autopilot and guarded against its return. #246
# deliberately reverses that: autopilot is reintroduced as the autopilot
# orchestrator, governed by the autopilot Iron Law. The guard is inverted — rules/
# now references autopilot ONLY via the autopilot Iron Law doc, so the revival stays
# governed and no ad-hoc / legacy autopilot rules creep back in.

@test "AC3 (#246): rules/atdd-kit.md references the autopilot Iron Law as a SCOPED override" {
  # Not a vacuous existence check: the reference must (a) point at the iron-law
  # doc, (b) state it OVERRIDES the standard laws, and (c) SCOPE that override to
  # while autopilot runs — so a stray ad-hoc ungoverned autopilot rule could not
  # satisfy all three.
  grep -qE 'autopilot-iron-law' "$RULES_FILE"
  grep -qiE 'autopilot.*overrides?' "$RULES_FILE"
  grep -qiE 'while `?autopilot`? runs' "$RULES_FILE"
  grep -qiE 'outside autopilot these laws are supreme' "$RULES_FILE"
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
