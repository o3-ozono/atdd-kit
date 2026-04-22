#!/usr/bin/env bats
# @covers: skills/discover/SKILL.md
# Tests for Issue #36: DoD + AC two-layer structure in discover skill

DISCOVER_SKILL="skills/discover/SKILL.md"
PLAN_SKILL="skills/plan/SKILL.md"

# --- AC1: DoD derivation step exists in all flows ---

@test "AC1: Development flow has DoD derivation step (Step 2.5)" {
  grep -q "Step 2.5" "$DISCOVER_SKILL"
}

@test "AC1: Development flow Step 2.5 mentions Definition of Done or DoD" {
  local step25
  step25=$(sed -n '/### Step 2\.5/,/### Step 3/p' "$DISCOVER_SKILL")
  echo "$step25" | grep -qi "Definition of Done\|DoD"
}

@test "AC1: Bug flow has DoD derivation step" {
  local bug_flow
  bug_flow=$(sed -n '/## Bug Flow/,/## Refactoring Flow/p' "$DISCOVER_SKILL")
  echo "$bug_flow" | grep -qi "DoD\|Definition of Done"
}

@test "AC1: Documentation/Research flow has DoD derivation step" {
  local docs_flow
  docs_flow=$(sed -n '/## Documentation/,/## Skill Completion/p' "$DISCOVER_SKILL")
  echo "$docs_flow" | grep -qi "DoD\|Definition of Done"
}

# --- AC2: evals.json has DoD assertions for code-change tasks ---

@test "AC2: evals.json dev-feature eval has DoD assertion A8" {
  grep -q '"id": "A8"' skills/discover/evals/evals.json
}

@test "AC2: evals.json dev-feature eval has DoD assertion A9" {
  grep -q '"id": "A9"' skills/discover/evals/evals.json
}

@test "AC2: evals.json bug-fix eval has DoD assertion B6" {
  grep -q '"id": "B6"' skills/discover/evals/evals.json
}

# --- AC3: documentation eval updated for DoD-only output ---

@test "AC3: evals.json documentation eval has C5 assertion (no Completion Criteria)" {
  grep -q '"id": "C5"' skills/discover/evals/evals.json
}

@test "AC3: evals.json documentation eval C2 references DoD" {
  grep -A2 '"id": "C2"' skills/discover/evals/evals.json | grep -qi "DoD\|Definition of Done"
}

# --- AC4: Completion Criteria terminology removed ---

@test "AC4: discover SKILL.md has no 'Completion Criteria' (capitalized)" {
  ! grep -q "Completion Criteria" "$DISCOVER_SKILL"
}

@test "AC4: discover SKILL.md has no 'completion criteria' (lowercase)" {
  ! grep -qi "completion criteria" "$DISCOVER_SKILL"
}

@test "AC4: docs/workflow/issue-ready-flow.md has no 'completion criteria'" {
  ! grep -qi "completion criteria" docs/workflow/issue-ready-flow.md
}

@test "AC4: commands/autopilot.md has no 'completion criteria'" {
  ! grep -qi "completion criteria" commands/autopilot.md
}

@test "AC4: plan SKILL.md has no 'completion criteria'" {
  ! grep -qi "completion criteria" "$PLAN_SKILL"
}

# --- AC5: DoD section is placed first in issue comment templates ---

@test "AC5: Development flow template has DoD section before Approach section" {
  local template
  template=$(sed -n '/## discover Deliverables/,/### Approach/p' "$DISCOVER_SKILL" | head -20)
  local dod_line approach_line
  dod_line=$(echo "$template" | grep -n "DoD\|Definition of Done" | head -1 | cut -d: -f1)
  approach_line=$(echo "$template" | grep -n "### Approach" | head -1 | cut -d: -f1)
  [[ -n "$dod_line" ]] && [[ -n "$approach_line" ]] && [[ "$dod_line" -lt "$approach_line" ]]
}

@test "AC5: Bug flow template has DoD section before Root Cause section" {
  # Extract only the Issue comment template block within Bug Flow (after "Format:" heading)
  local bug_template
  bug_template=$(sed -n '/## Bug Flow/,/## Refactoring Flow/p' "$DISCOVER_SKILL" | sed -n '/^```markdown/,/^```$/p')
  local dod_line rootcause_line
  dod_line=$(echo "$bug_template" | grep -n "DoD\|Definition of Done" | head -1 | cut -d: -f1)
  rootcause_line=$(echo "$bug_template" | grep -n "Root Cause" | head -1 | cut -d: -f1)
  [[ -n "$dod_line" ]] && [[ -n "$rootcause_line" ]] && [[ "$dod_line" -lt "$rootcause_line" ]]
}

@test "AC5: Documentation/Research flow template has DoD section before Scope section" {
  local docs_flow
  docs_flow=$(sed -n '/## Documentation/,/## Skill Completion/p' "$DISCOVER_SKILL")
  local dod_line scope_line
  dod_line=$(echo "$docs_flow" | grep -n "DoD\|Definition of Done" | head -1 | cut -d: -f1)
  scope_line=$(echo "$docs_flow" | grep -n "### Scope" | head -1 | cut -d: -f1)
  [[ -n "$dod_line" ]] && [[ -n "$scope_line" ]] && [[ "$dod_line" -lt "$scope_line" ]]
}

# --- AC6: Bug flow deliverables include DoD section ---

@test "AC6: Bug flow template includes DoD section" {
  local bug_flow
  bug_flow=$(sed -n '/## Bug Flow/,/## Refactoring Flow/p' "$DISCOVER_SKILL")
  echo "$bug_flow" | grep -q "DoD\|Definition of Done"
}

# --- AC7: Refactoring flow has required DoD item for behavioral invariance ---

@test "AC7: Refactoring flow mentions externally observable behavior unchanged as DoD item" {
  local refactoring_section
  refactoring_section=$(sed -n '/## Refactoring Flow/,/## Documentation/p' "$DISCOVER_SKILL")
  echo "$refactoring_section" | grep -qiE "observable.behavior|behavior.unchanged|externally.visible|externally observable"
}

# --- AC8: plan skill reads new DoD header ---

@test "AC8: plan SKILL.md Step 1 mentions DoD as discover deliverable" {
  local step1
  step1=$(sed -n '/### Step 1: Read discover Deliverables/,/### Step 2/p' "$PLAN_SKILL")
  echo "$step1" | grep -qi "DoD"
}

@test "AC8: plan SKILL.md description field mentions DoD" {
  head -5 "$PLAN_SKILL" | grep -qi "DoD"
}

# --- Mandatory Checklist check ---

@test "Mandatory Checklist includes DoD derivation step check" {
  local checklist
  checklist=$(sed -n '/## Mandatory Checklist/,$p' "$DISCOVER_SKILL")
  echo "$checklist" | grep -qi "DoD\|Definition of Done"
}

# --- Regression: existing behaviors are preserved ---

@test "Regression: discover AUTOPILOT-GUARD uses --autopilot flag" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER_SKILL")
  echo "$guard" | grep -q '\-\-autopilot'
}

@test "Regression: Development flow UX check U1-U5 is preserved" {
  grep -q "U1" "$DISCOVER_SKILL"
  grep -q "U5" "$DISCOVER_SKILL"
}

@test "Regression: Development flow interruption scenarios I1-I4 are preserved" {
  grep -q "I1" "$DISCOVER_SKILL"
  grep -q "I4" "$DISCOVER_SKILL"
}

@test "Regression: Step 2 approach exploration equal-detail rule is preserved" {
  local step2
  step2=$(sed -n '/### Step 2: Approach Exploration/,/### Step 2\.5/p' "$DISCOVER_SKILL")
  echo "$step2" | grep -qi "equal\|same level of detail"
}
