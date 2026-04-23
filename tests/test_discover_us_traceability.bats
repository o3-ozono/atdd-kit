#!/usr/bin/env bats
# @covers: skills/discover/SKILL.md
# Issue #156: AC must be traceable to User Story elements

DISCOVER_SKILL="skills/discover/SKILL.md"

# Helper: extract Step 4 section (between Step 4 heading and Step 4.5 heading)
step4_section() {
  sed -n '/### Step 4: Acceptance Criteria Derivation/,/### Step 4\.5/p' "$DISCOVER_SKILL"
}

# Helper: extract Step 4.5 section (between Step 4.5 heading and Step 5 heading)
step45_section() {
  sed -n '/### Step 4\.5: US\/AC Quality Validation/,/### Step 5/p' "$DISCOVER_SKILL"
}

# --- AC1: US traceability table format in Step 4 ---

@test "AC1: discover Step 4 contains US traceability table format" {
  step4_section | grep -qE '\|\s*US.*(element|Element).*\|.*AC.*\|'
}

@test "AC1: discover Step 4 instructs each AC to map to a US element" {
  step4_section | grep -qi 'user story element\|US element\|map.*AC\|AC.*map\|correspond.*US\|trace'
}

# --- AC2: Exclusion list in Step 4 ---

@test "AC2: discover Step 4 contains exclusion list with DoD category" {
  step4_section | grep -qi 'DoD\|Definition of Done'
}

@test "AC2: discover Step 4 contains exclusion list with trivial-consequence category" {
  step4_section | grep -qi 'trivial\|obvious consequence\|logical consequence\|implied'
}

@test "AC2: discover Step 4 contains exclusion list with implementation guard category" {
  step4_section | grep -qi 'implementation.*guard\|impl.*guard\|implementation note'
}

@test "AC2: discover Step 4 contains exclusion list with future-story category" {
  step4_section | grep -qi 'future.*story\|future story\|future.*scope\|extensib'
}

@test "AC2: discover Step 4 states detailed definitions are in Step 4.5 MUST-4" {
  step4_section | grep -qi 'MUST-4\|Step 4\.5\|single.*source\|detail.*defin'
}

# --- AC3: MUST-4 in Step 4.5 ---

@test "AC3: discover Step 4.5 MUST table contains MUST-4 row" {
  step45_section | grep -qE '^\|.*MUST-4.*\|'
}

@test "AC3: discover Step 4.5 MUST-4 requires each AC to map to at least one US element" {
  step45_section | grep -qi 'MUST-4\|US.*trace\|trace.*US'
  step45_section | grep -qi 'at least one\|one.*US element\|specific.*US'
}

@test "AC3: discover Step 4.5 MUST-4 lists fail markers - project conventions" {
  step45_section | grep -qi 'project.*convent\|CI green\|warning.*zero\|lint\|coverage'
}

@test "AC3: discover Step 4.5 MUST-4 lists fail markers - trivial consequence" {
  step45_section | grep -qi 'trivial\|obvious\|logical consequence\|implied'
}

@test "AC3: discover Step 4.5 MUST-4 lists fail markers - implementation guard" {
  step45_section | grep -qi 'implementation.*guard\|impl.*guard'
}

@test "AC3: discover Step 4.5 MUST-4 lists fail markers - future story" {
  step45_section | grep -qi 'future.*story\|future story\|future.*scope'
}

@test "AC3: discover Step 4.5 MUST-4 includes rewrite suggestions for each fail marker" {
  step45_section | grep -qi 'move.*DoD\|DoD.*move\|consolidat\|Implementation note\|test strategy\|plan'
}

@test "AC3: discover Step 4.5 MUST-4 references us-quality-standard.md as single source" {
  step45_section | grep -qi 'us-quality-standard\|single.*source\|single.*defin'
}

@test "AC3: discover Step 4.5 MUST-4 specifies same autopilot failure behavior as MUST-1/2/3" {
  step45_section | grep -qi 'autopilot\|AC Review Round\|same.*behavior\|same.*MUST'
}

@test "AC3: discover Step 4.5 MUST-4 notes no retroactive application to existing specs" {
  step45_section | grep -qi 'retroactive\|existing.*spec\|no.*retro\|not.*apply.*existing'
}
