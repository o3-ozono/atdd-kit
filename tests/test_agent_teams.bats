#!/usr/bin/env bats

# AC1-AC6: Agent Teams architecture tests (replaces test_autopilot.bats)

# --- AC1: Polling loop files are deleted ---

@test "AC1: scripts/autopilot.sh does not exist" {
  [[ ! -f scripts/autopilot.sh ]]
}

@test "AC1: templates/autopilot.sh.tmpl does not exist" {
  [[ ! -f templates/autopilot.sh.tmpl ]]
}

@test "AC1: tests/test_autopilot.bats does not exist" {
  [[ ! -f tests/test_autopilot.bats ]]
}

# --- AC2: autopilot command is Agent Teams launcher ---

@test "AC2: autopilot.md exists" {
  [[ -f commands/autopilot.md ]]
}

@test "AC2: autopilot.md references Agent Teams" {
  grep -qi 'agent.*teams' commands/autopilot.md
}

@test "AC2: autopilot.md does not reference /loop" {
  ! grep -q '/loop' commands/autopilot.md
}

@test "AC2: autopilot.md does not reference polling_interval" {
  ! grep -qi 'polling_interval' commands/autopilot.md
}

@test "AC2: autopilot.md does not reference autopilot.sh" {
  ! grep -q 'autopilot\.sh' commands/autopilot.md
}

# --- AC3: workflow-config template no longer exists (system_prompt moved to agents/) ---

@test "AC3: workflow-config template no longer exists" {
  [[ ! -f templates/workflow-config.yml.tmpl ]]
}

@test "AC3: system_prompt is now in agents/ directory" {
  grep -q 'system_prompt\|You are' agents/po.md
  grep -q 'system_prompt\|You are' agents/developer.md
  grep -q 'system_prompt\|You are' agents/qa.md
}

@test "AC3: .claude/workflow-config.yml has no polling_interval" {
  ! grep -q 'polling_interval' .claude/workflow-config.yml
}

@test "AC3: .claude/workflow-config.yml has no startup_script" {
  ! grep -q 'startup_script' .claude/workflow-config.yml
}

# --- AC4: Document consistency ---

@test "AC4: docs/workflow-detail.md has no polling loop reference" {
  ! grep -qi 'polling.*loop\|bash.*polling' docs/workflow-detail.md
}

@test "AC4: docs/workflow-detail.md has no autopilot.sh reference" {
  ! grep -q 'autopilot\.sh' docs/workflow-detail.md
}

@test "AC4: docs/workflow-detail.md references Agent Teams" {
  grep -qi 'agent.*teams' docs/workflow-detail.md
}

@test "AC4: README.md has no polling loop reference" {
  ! grep -qi 'polling.*loop\|bash.*polling' README.md
}

@test "AC4: README.md has no autopilot.sh reference" {
  ! grep -q 'autopilot\.sh' README.md
}

@test "AC4: README.ja.md has no polling loop reference" {
  ! grep -qi 'polling\|ポーリング' README.ja.md
}

@test "AC4: README.ja.md has no autopilot.sh reference" {
  ! grep -q 'autopilot\.sh' README.ja.md
}

@test "AC4: DEVELOPMENT.md has no /loop reference" {
  ! grep -q '/loop' DEVELOPMENT.md
}

@test "AC4: DEVELOPMENT.ja.md has no /loop reference" {
  ! grep -q '/loop' DEVELOPMENT.ja.md
}

@test "AC4: commands/README.md has no /loop reference" {
  ! grep -q '/loop' commands/README.md
}

@test "AC4: templates/README.md has no autopilot.sh.tmpl reference" {
  ! grep -q 'autopilot\.sh\.tmpl' templates/README.md
}

@test "AC4: skills/plan/SKILL.md has no autopilot loop reference" {
  ! grep -qi 'autopilot.*loop' skills/plan/SKILL.md
}

@test "AC4: scripts/README.md has no autopilot.sh reference" {
  ! grep -q 'autopilot\.sh' scripts/README.md
}

# --- AC5: utility commands still exist ---

@test "AC5: auto-sweep.md exists" {
  [[ -f commands/auto-sweep.md ]]
}

@test "AC5: auto-eval.md exists" {
  [[ -f commands/auto-eval.md ]]
}

@test "AC5: auto-implement.md and auto-review.md are removed (consolidated into autopilot)" {
  [[ ! -f commands/auto-implement.md ]]
  [[ ! -f commands/auto-review.md ]]
}

# --- AC6: CHANGELOG updated ---
# (AC6 CHANGELOG entry test removed -- the entry moved out of [Unreleased] when v0.9.0 was released)
