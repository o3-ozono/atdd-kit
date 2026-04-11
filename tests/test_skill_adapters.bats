#!/usr/bin/env bats

# skill_adapters moved to agents/ frontmatter.
# Tests validate agents/*.md structure and skill-gate governance.

# AC1: Agent definitions have proper frontmatter structure

@test "agents/developer.md has skills field in frontmatter" {
  grep -q 'skills:' agents/developer.md
}

@test "agents/developer.md has atdd-kit:atdd skill" {
  grep -q 'atdd-kit:atdd' agents/developer.md
}

@test "agents/developer.md has atdd-kit:verify skill" {
  grep -q 'atdd-kit:verify' agents/developer.md
}

@test "agents/po.md has name field in frontmatter" {
  grep -q 'name:' agents/po.md
}

@test "agents/qa.md has name field in frontmatter" {
  grep -q 'name:' agents/qa.md
}

@test "agents/researcher.md has name field in frontmatter" {
  grep -q 'name:' agents/researcher.md
}

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

@test "skill-gate routes Issue work to autopilot" {
  grep -q 'autopilot' skills/skill-gate/SKILL.md
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

# ideate skill

@test "ideate SKILL.md exists" {
  [[ -f skills/ideate/SKILL.md ]]
}

@test "ideate has description for auto-trigger" {
  grep -q 'description:' skills/ideate/SKILL.md
}

@test "ideate documents approach comparison" {
  grep -qi 'pros\|cons\|approach' skills/ideate/SKILL.md
}

@test "ideate prohibits code edits" {
  grep -qi 'no code\|no file\|禁止\|prohibition' skills/ideate/SKILL.md
}

@test "ideate chains to issue skill in pre-Issue mode" {
  grep -q 'atdd-kit:issue' skills/ideate/SKILL.md
}

# AC2: ideate post-Issue mode

@test "ideate documents post-Issue mode" {
  grep -qi 'post-Issue' skills/ideate/SKILL.md
}

@test "ideate chains to discover in post-Issue mode" {
  grep -q 'atdd-kit:discover' skills/ideate/SKILL.md
}

@test "ideate detects mode by Issue number argument" {
  grep -qi 'issue.*number\|issue.*argument\|Issue.*exist' skills/ideate/SKILL.md
}

# AC3: ideate skip functionality

@test "ideate documents skip option in post-Issue mode" {
  grep -qi 'skip.*discover\|skip.*brainstorm\|Skip to discover' skills/ideate/SKILL.md
}

# AC5: pre-Issue mode preserved

@test "ideate preserves pre-Issue mode with issue chain" {
  # pre-Issue mode still chains to issue
  grep -q 'atdd-kit:issue' skills/ideate/SKILL.md
}

@test "ideate documents pre-Issue mode" {
  grep -qi 'pre-Issue' skills/ideate/SKILL.md
}

# AC1: issue chains to ideate (not directly to discover)

@test "issue Step 4 chains to ideate skill" {
  grep -q 'atdd-kit:ideate' skills/issue/SKILL.md
}

@test "issue Step 4 does not chain directly to discover" {
  # issue should chain to ideate, not discover directly
  # The Step 4 section should reference ideate, not discover as the chain target
  run grep -A5 '## Step 4' skills/issue/SKILL.md
  [[ "$output" == *"ideate"* ]]
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

# autopilot agent configuration

@test "autopilot references agents/ directory" {
  grep -q 'agents/' commands/autopilot.md
}

@test "autopilot uses subagent_type for agent spawning" {
  grep -q 'subagent_type' commands/autopilot.md
}
