#!/usr/bin/env bats
# @covers: agents/**
# skill_adapters moved to agents/ frontmatter.
# Tests validate agents/*.md structure and skill-gate governance.

@test "no workflow-config template with skill_adapters section" {
  [[ ! -f "templates/workflow-config.yml.tmpl" ]]
}

# AC2: skill-gate skill (unchanged — governance enforcement)

@test "skill-gate SKILL.md exists" {
  [[ -f skills/skill-gate/SKILL.md ]]
}

@test "skill-gate has auto-trigger description" {
  grep -q 'description:' skills/skill-gate/SKILL.md
}

@test "skill-gate has 3-layer structure: Pre-check, Governance Rules, Red Flags" {
  grep -q '## Pre-check' skills/skill-gate/SKILL.md
  grep -q '## Governance Rules' skills/skill-gate/SKILL.md
  grep -q '## Red Flags' skills/skill-gate/SKILL.md
}

@test "skill-gate enforces skill invocation before direct work" {
  grep -qi 'invoke.*before\|before.*work\|must.*check\|must.*invoke' skills/skill-gate/SKILL.md
}

# skill-gate governance rules

@test "skill-gate has Iron Law #1" {
  grep -q 'Iron Law #1' skills/skill-gate/SKILL.md
}

@test "skill-gate has 1% Rule" {
  grep -q '1% Rule\|1%.*chance' skills/skill-gate/SKILL.md
}

@test "skill-gate has Announcement Obligation" {
  grep -q 'Announcement Obligation' skills/skill-gate/SKILL.md
}

# skill-gate Issue Work Routing

@test "skill-gate has Issue Work Routing in Pre-check" {
  grep -q 'Issue Work Routing' skills/skill-gate/SKILL.md
}

@test "skill-gate routes Issue work to the v1.0 flow (defining-requirements)" {
  grep -q 'defining-requirements' skills/skill-gate/SKILL.md
  ! grep -q 'autopilot' skills/skill-gate/SKILL.md
}

@test "skill-gate does not contain adapter evaluation sections" {
  ! grep -q 'brainstorming' skills/skill-gate/SKILL.md
  ! grep -q '## Flow' skills/skill-gate/SKILL.md
  ! grep -q 'Adapter Resolution' skills/skill-gate/SKILL.md
}

# skill-gate governance focus: no adapter slots

@test "skill-gate focuses on governance enforcement" {
  grep -qi 'governance' skills/skill-gate/SKILL.md
}

# debugging skill

@test "debugging SKILL.md exists" {
  [[ -f skills/debugging/SKILL.md ]]
}

@test "debugging has description for auto-trigger" {
  grep -q 'description:' skills/debugging/SKILL.md
}

@test "debugging requires root cause classification" {
  grep -qE 'AC Gap|Test Gap|Logic Error' skills/debugging/SKILL.md
}

@test "debugging defines diagnostic flow" {
  grep -qi 'hypothesis\|diagnos' skills/debugging/SKILL.md
}

@test "debugging prohibits fix code during investigation" {
  grep -qi 'no fix\|no code\|do not write.*fix\|prohibition' skills/debugging/SKILL.md
}

