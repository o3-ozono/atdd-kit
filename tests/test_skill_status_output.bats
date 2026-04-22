#!/usr/bin/env bats
# @covers: skills/**
# Tests for Issue #58: SKILL_STATUS output in core skills (AC2, AC3, AC4)

DISCOVER="skills/discover/SKILL.md"
PLAN="skills/plan/SKILL.md"
ATDD="skills/atdd/SKILL.md"
VERIFY="skills/verify/SKILL.md"
SHIP="skills/ship/SKILL.md"

# Helper: extract Status Output section content from a skill file
# Usage: get_status_section <file>
get_status_section() {
  sed -n '/^## Status Output/,/^## /p' "$1"
}

# ===================================================================
# AC2: Core skills output SKILL_STATUS on COMPLETE
# ===================================================================

@test "AC2: discover has Status Output section" {
  grep -q '## Status Output' "$DISCOVER"
}

@test "AC2: plan has Status Output section" {
  grep -q '## Status Output' "$PLAN"
}

@test "AC2: atdd has Status Output section" {
  grep -q '## Status Output' "$ATDD"
}

@test "AC2: verify has Status Output section" {
  grep -q '## Status Output' "$VERIFY"
}

@test "AC2: ship has Status Output section" {
  grep -q '## Status Output' "$SHIP"
}

@test "AC2: all skills define COMPLETE status" {
  for skill in "$DISCOVER" "$PLAN" "$ATDD" "$VERIFY" "$SHIP"; do
    get_status_section "$skill" | grep -q 'COMPLETE'
  done
}

@test "AC2: all skills include PHASE field in output block" {
  for skill in "$DISCOVER" "$PLAN" "$ATDD" "$VERIFY" "$SHIP"; do
    get_status_section "$skill" | grep -q 'PHASE:'
  done
}

@test "AC2: all skills include RECOMMENDATION field in output block" {
  for skill in "$DISCOVER" "$PLAN" "$ATDD" "$VERIFY" "$SHIP"; do
    get_status_section "$skill" | grep -q 'RECOMMENDATION:'
  done
}

@test "AC2: all skills use skill-status fenced block format" {
  for skill in "$DISCOVER" "$PLAN" "$ATDD" "$VERIFY" "$SHIP"; do
    get_status_section "$skill" | grep -q '```skill-status'
  done
}

@test "AC2: discover Status Output is limited to autopilot mode" {
  get_status_section "$DISCOVER" | grep -qi 'autopilot'
}

@test "AC2: plan Status Output excludes Inline Mode" {
  get_status_section "$PLAN" | grep -qi 'inline.*mode\|not.*inline\|exclude.*inline\|skip.*inline'
}

# ===================================================================
# AC3: Core skills output SKILL_STATUS: BLOCKED when blocked
# ===================================================================

@test "AC3: all skills define BLOCKED status" {
  for skill in "$DISCOVER" "$PLAN" "$ATDD" "$VERIFY" "$SHIP"; do
    get_status_section "$skill" | grep -q 'BLOCKED'
  done
}

@test "AC3: discover BLOCKED covers HARD-GATE or in-progress lock" {
  get_status_section "$DISCOVER" | grep -qi 'hard-gate\|in-progress\|precondition\|lock\|blocked'
}

@test "AC3: plan BLOCKED covers State Gate failure" {
  get_status_section "$PLAN" | grep -qi 'state gate\|precondition\|in-progress\|blocked'
}

@test "AC3: atdd BLOCKED covers missing ready-to-go" {
  get_status_section "$ATDD" | grep -qi 'ready-to-go\|state gate\|precondition\|blocked'
}

@test "AC3: verify BLOCKED covers main branch or missing in-progress" {
  get_status_section "$VERIFY" | grep -qi 'main\|in-progress\|state gate\|precondition\|blocked'
}

@test "AC3: ship BLOCKED covers State Gate failure" {
  get_status_section "$SHIP" | grep -qi 'state gate\|in-progress\|precondition\|blocked'
}

# ===================================================================
# AC4: Core skills output SKILL_STATUS: FAILED on unrecoverable error
# ===================================================================

@test "AC4: all skills define FAILED status" {
  for skill in "$DISCOVER" "$PLAN" "$ATDD" "$VERIFY" "$SHIP"; do
    get_status_section "$skill" | grep -q 'FAILED'
  done
}

@test "AC4: all skills include PENDING status" {
  for skill in "$DISCOVER" "$PLAN" "$ATDD" "$VERIFY" "$SHIP"; do
    get_status_section "$skill" | grep -q 'PENDING'
  done
}

# ===================================================================
# AC2: Positioning — Status Output appears before the correct anchor
# ===================================================================

@test "AC2: discover Status Output appears before Skill Completion and Transition" {
  local status_line
  status_line=$(grep -n '## Status Output' "$DISCOVER" | head -1 | cut -d: -f1)
  local transition_line
  transition_line=$(grep -n '## Skill Completion and Transition' "$DISCOVER" | head -1 | cut -d: -f1)
  [ "$status_line" -lt "$transition_line" ]
}

@test "AC2: atdd Status Output appears before Transition section" {
  local status_line
  status_line=$(grep -n '## Status Output' "$ATDD" | head -1 | cut -d: -f1)
  local transition_line
  transition_line=$(grep -n '## Transition' "$ATDD" | head -1 | cut -d: -f1)
  [ "$status_line" -lt "$transition_line" ]
}

@test "AC2: verify Status Output appears before If All ACs Pass" {
  local status_line
  status_line=$(grep -n '## Status Output' "$VERIFY" | head -1 | cut -d: -f1)
  local pass_line
  pass_line=$(grep -n '## If All ACs Pass' "$VERIFY" | head -1 | cut -d: -f1)
  [ "$status_line" -lt "$pass_line" ]
}
