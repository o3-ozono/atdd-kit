#!/usr/bin/env bats
# @covers: skills/**
# Tests for Issue #108: ATDD workflow enforcement — State Gates

SKILL_GATE="skills/skill-gate/SKILL.md"
PLAN_SKILL="skills/plan/SKILL.md"
ATDD_SKILL="skills/atdd/SKILL.md"
VERIFY_SKILL="skills/verify/SKILL.md"
SHIP_SKILL="skills/ship/SKILL.md"

# ============================================================
# AC1: skill-gate Iron Law #1
# ============================================================

@test "AC1: skill-gate has Iron Law #1 section" {
  grep -q 'Iron Law #1' "$SKILL_GATE"
}

@test "AC1: skill-gate Red Flags table has Issue-less implementation row" {
  sed -n '/## Red Flags/,/^## /p' "$SKILL_GATE" | grep -qi 'issue\|code without'
}

@test "AC1: skill-gate guides user to create Issue first" {
  grep -qi 'issue.*creat\|creat.*issue\|guide.*issue\|suggest.*issue' "$SKILL_GATE"
}

# ============================================================
# AC2: plan State Gate
# ============================================================

@test "AC2: plan SKILL.md contains State Gate section" {
  grep -q 'State Gate' "$PLAN_SKILL"
}

@test "AC2: plan State Gate checks in-progress label" {
  sed -n '/State Gate/,/^## /p' "$PLAN_SKILL" | grep -q 'in-progress'
}

@test "AC2: plan State Gate checks discover deliverables" {
  sed -n '/State Gate/,/^## /p' "$PLAN_SKILL" | grep -qi 'discover.*deliverables\|deliverables'
}

@test "AC2: plan State Gate is positioned after HARD-GATE" {
  local hard_gate_line
  hard_gate_line=$(grep -n '</HARD-GATE>' "$PLAN_SKILL" | head -1 | cut -d: -f1)
  local state_gate_line
  state_gate_line=$(grep -n 'State Gate' "$PLAN_SKILL" | head -1 | cut -d: -f1)
  [ "$state_gate_line" -gt "$hard_gate_line" ]
}

@test "AC2: plan State Gate refuses when preconditions not met" {
  sed -n '/State Gate/,/^## /p' "$PLAN_SKILL" | grep -qi 'stop\|missing'
}

# ============================================================
# AC3: atdd State Gate
# ============================================================

@test "AC3: atdd SKILL.md contains State Gate section" {
  grep -q 'State Gate' "$ATDD_SKILL"
}

@test "AC3: atdd State Gate checks ready-to-go label" {
  sed -n '/State Gate/,/^## /p' "$ATDD_SKILL" | grep -q 'ready-to-go'
}

@test "AC3: atdd State Gate removes ready-to-go and adds in-progress" {
  sed -n '/State Gate/,/^## /p' "$ATDD_SKILL" | grep -qi 'remove.*ready-to-go'
  sed -n '/State Gate/,/^## /p' "$ATDD_SKILL" | grep -qi 'in-progress'
}

@test "AC3: atdd State Gate refuses without ready-to-go" {
  sed -n '/State Gate/,/^## /p' "$ATDD_SKILL" | grep -qi 'stop\|not ready'
}

# ============================================================
# AC4: verify/ship State Gate
# ============================================================

@test "AC4: verify SKILL.md contains State Gate section" {
  grep -q 'State Gate' "$VERIFY_SKILL"
}

@test "AC4: verify State Gate checks in-progress label" {
  sed -n '/State Gate/,/^## /p' "$VERIFY_SKILL" | grep -q 'in-progress'
}

@test "AC4: verify State Gate checks implementation branch" {
  sed -n '/State Gate/,/^## /p' "$VERIFY_SKILL" | grep -qi 'branch\|main'
}

@test "AC4: verify State Gate refuses without in-progress" {
  sed -n '/State Gate/,/^## /p' "$VERIFY_SKILL" | grep -qi 'stop\|missing'
}

@test "AC4: ship SKILL.md contains State Gate section" {
  grep -q 'State Gate' "$SHIP_SKILL"
}

@test "AC4: ship State Gate checks in-progress label" {
  sed -n '/State Gate/,/^## /p' "$SHIP_SKILL" | grep -q 'in-progress'
}

@test "AC4: ship State Gate refuses without in-progress" {
  sed -n '/State Gate/,/^## /p' "$SHIP_SKILL" | grep -qi 'stop\|missing'
}

# ============================================================
# AC5: Continuation path
# ============================================================

@test "AC5: atdd State Gate has continuation path" {
  sed -n '/State Gate/,/^## /p' "$ATDD_SKILL" | grep -qi 'continu\|resume'
}

@test "AC5: continuation uses branch name matching" {
  sed -n '/State Gate/,/^## /p' "$ATDD_SKILL" | grep -qi 'branch.*match\|<prefix>.*<issue'
}

@test "AC5: in-progress with matching branch allows continuation" {
  sed -n '/State Gate/,/^## /p' "$ATDD_SKILL" | grep -qi 'in-progress.*continu\|session.*resumption\|do not block'
}

# ============================================================
# AC6: Normal flow not broken (structural checks)
# ============================================================

@test "AC6: plan still has Core Flow section" {
  grep -q '## Core Flow' "$PLAN_SKILL"
}

@test "AC6: atdd still has Double Loop section" {
  grep -q '## The Double Loop' "$ATDD_SKILL"
}

@test "AC6: verify still has Verification Flow section" {
  grep -q '## Verification Flow' "$VERIFY_SKILL"
}

@test "AC6: ship still has Flow section" {
  grep -q '## Flow' "$SHIP_SKILL"
}

@test "AC6: plan Inline Mode section preserved" {
  grep -q 'Inline Mode' "$PLAN_SKILL"
}

@test "AC6: plan Inline Mode mentions State Gate skip" {
  grep -qi 'inline.*mode\|skip.*gate\|skip.*step' "$PLAN_SKILL"
}
