#!/usr/bin/env bats

# Tests for Issue #145: discover approach comparison equal-detail rules

DISCOVER_SKILL="skills/discover/SKILL.md"

# Helper: extract Step 2 section (between Step 2 heading and Step 3 heading)
step2_section() {
  sed -n '/### Step 2: Approach Exploration/,/### Step 3/p' "$DISCOVER_SKILL"
}

# --- AC1: Equal-detail rule for all approaches ---

@test "AC1: discover Step 2 contains equal-detail rule for all approaches" {
  step2_section | grep -qi 'equal\|same level of detail'
}

@test "AC1: equal-detail rule mentions Summary, Pros, Cons, Impact, Risks" {
  local rule_line
  rule_line=$(step2_section | grep -i 'equal\|same level of detail')
  echo "$rule_line" | grep -qi 'Summary'
  echo "$rule_line" | grep -qi 'Pros'
  echo "$rule_line" | grep -qi 'Cons'
  echo "$rule_line" | grep -qi 'Impact'
  echo "$rule_line" | grep -qi 'Risks'
}

# --- AC2: Minimum 2-item guard for Pros/Cons ---

@test "AC2: discover Step 2 contains minimum item guard for Pros/Cons" {
  step2_section | grep -qi 'minimum\|at least'
}

@test "AC2: minimum detail guard specifies 2 items" {
  step2_section | grep -i 'minimum\|at least' | grep -q '2'
}

@test "AC2: minimum detail guard mentions Pros and Cons" {
  local guard_line
  guard_line=$(step2_section | grep -i 'minimum\|at least')
  echo "$guard_line" | grep -qi 'Pros'
  echo "$guard_line" | grep -qi 'Cons'
}
