#!/usr/bin/env bats
# @covers: skills/defining-requirements skills/extracting-user-stories skills/writing-plan-and-tests skills/running-atdd-cycle skills/reviewing-deliverables skills/merging-and-deploying skills/launching-preview skills/writing-design-doc

setup() {
  # All 8 v1 capability skills — checks that apply regardless of skeleton
  # vs implemented state (existence, naming, "Use when" prefix).
  V1_SKILLS=(
    defining-requirements
    extracting-user-stories
    writing-plan-and-tests
    running-atdd-cycle
    reviewing-deliverables
    merging-and-deploying
    launching-preview
    writing-design-doc
  )
  # Skills still in the skeleton state from #185. Each B PR (B1=#188 …
  # B8=#195) removes its own entry when implemented.
  SKELETON_SKILLS=(
    extracting-user-stories
    writing-plan-and-tests
    running-atdd-cycle
    reviewing-deliverables
    merging-and-deploying
    launching-preview
    writing-design-doc
  )
}

# --- AC1: All 8 skeleton SKILL.md files exist ---

@test "all v1 skeleton SKILL.md files exist" {
  for skill in "${V1_SKILLS[@]}"; do
    [[ -f "skills/${skill}/SKILL.md" ]]
  done
}

# --- AC2: name field matches directory name (kebab-case) ---

@test "all v1 skeleton SKILL.md name field matches directory name" {
  for skill in "${V1_SKILLS[@]}"; do
    local name
    name=$(grep '^name:' "skills/${skill}/SKILL.md" | sed 's/^name:[[:space:]]*//')
    [[ "$name" == "$skill" ]]
  done
}

@test "all v1 skeleton SKILL.md name field is kebab-case" {
  for skill in "${V1_SKILLS[@]}"; do
    local name
    name=$(grep '^name:' "skills/${skill}/SKILL.md" | sed 's/^name:[[:space:]]*//')
    [[ "$name" =~ ^[a-z][a-z0-9-]+$ ]]
  done
}

# --- AC2: description starts with "Use when" ---

@test "all v1 skeleton SKILL.md description starts with Use when" {
  for skill in "${V1_SKILLS[@]}"; do
    local desc
    desc=$(grep '^description:' "skills/${skill}/SKILL.md" | sed 's/^description:[[:space:]]*//' | tr -d '"')
    [[ "$desc" == "Use when"* ]]
  done
}

# --- AC3: HARD-GATE block with stop instruction ---

@test "all v1 skeleton SKILL.md have HARD-GATE block" {
  for skill in "${SKELETON_SKILLS[@]}"; do
    grep -q '<HARD-GATE>' "skills/${skill}/SKILL.md"
  done
}

@test "all v1 skeleton SKILL.md contain not yet implemented message" {
  for skill in "${SKELETON_SKILLS[@]}"; do
    grep -q 'not yet implemented' "skills/${skill}/SKILL.md"
  done
}

@test "all v1 skeleton SKILL.md contain stop instruction" {
  for skill in "${SKELETON_SKILLS[@]}"; do
    grep -q 'Stop\. Do not proceed\.' "skills/${skill}/SKILL.md"
  done
}

# --- AC4: Integration section with Upstream/Downstream placeholders ---

@test "all v1 skeleton SKILL.md have Integration section" {
  for skill in "${V1_SKILLS[@]}"; do
    grep -q '^## Integration' "skills/${skill}/SKILL.md"
  done
}

@test "all v1 skeleton SKILL.md have Upstream placeholder" {
  for skill in "${V1_SKILLS[@]}"; do
    grep -q 'Upstream:' "skills/${skill}/SKILL.md"
  done
}

@test "all v1 skeleton SKILL.md have Downstream placeholder" {
  for skill in "${V1_SKILLS[@]}"; do
    grep -q 'Downstream:' "skills/${skill}/SKILL.md"
  done
}

# --- AC5: Each SKILL.md is 50 lines or fewer ---

@test "all v1 skeleton SKILL.md are 50 lines or fewer" {
  for skill in "${SKELETON_SKILLS[@]}"; do
    local lines
    lines=$(wc -l < "skills/${skill}/SKILL.md")
    [[ "$lines" -le 50 ]]
  done
}
