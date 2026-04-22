#!/usr/bin/env bats
# @covers: .claude-plugin/**
# Issue #34 AC2: Task-type-specific agent composition switching
# Issue #34 AC3: Variable-count agent user approval

AUTOPILOT="commands/autopilot.md"

# --- AC2: Task type agent composition table ---

@test "AC2: autopilot.md has agent composition table" {
  grep -q 'development.*PO.*Developer' "$AUTOPILOT"
  grep -q 'bug.*PO.*Tester' "$AUTOPILOT"
  grep -q 'research.*PO.*Researcher' "$AUTOPILOT"
  grep -q 'documentation.*PO.*Writer' "$AUTOPILOT"
  grep -q 'refactoring.*PO.*Developer' "$AUTOPILOT"
}

@test "AC2: autopilot.md reads task type label in Phase 0.5" {
  sed -n '/Phase 0.5/,/^## Phase/p' "$AUTOPILOT" | grep -q 'type:development\|type:bug\|type:research\|type:documentation\|type:refactoring'
}

@test "AC2: autopilot.md Phase 0.9 spawns agents by task type" {
  sed -n '/Phase 0.9/,/^## Phase/p' "$AUTOPILOT" | grep -qi 'task.type\|agent.*composition\|spawn.*based'
}

@test "AC2: autopilot.md has development flow in AC Review Round" {
  grep -qi 'development.*Three Amigos\|development.*refactoring.*PO.*Developer.*QA' "$AUTOPILOT"
}

@test "AC2: autopilot.md has bug Phase 1 flow" {
  grep -qi 'bug.*Phase 1\|bug.*triage\|bug.*Tester' "$AUTOPILOT"
}

@test "AC2: autopilot.md has research Phase 2 flow" {
  grep -qi 'research.*Phase 2\|research.*Researcher' "$AUTOPILOT"
}

@test "AC2: autopilot.md has documentation Phase 2 flow" {
  grep -qi 'documentation.*Phase 2\|documentation.*Writer' "$AUTOPILOT"
}

# --- AC3: Variable-count agent user approval ---

@test "AC3: autopilot.md mentions variable count for Reviewer" {
  grep -qi 'Reviewer.*x.*N\|Reviewer.*variable\|Reviewer.*人数' "$AUTOPILOT"
}

@test "AC3: autopilot.md mentions variable count for Researcher" {
  grep -qi 'Researcher.*x.*N\|Researcher.*variable\|Researcher.*人数' "$AUTOPILOT"
}

@test "AC3: autopilot.md requires user approval before spawning variable agents" {
  grep -qi 'user.*approv\|ユーザー.*承認\|confirm.*before.*spawn\|承認.*spawn' "$AUTOPILOT"
}
