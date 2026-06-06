#!/usr/bin/env bats
# @covers: skills/**
# Skill lists for structure validation
setup() {
  ALL_SKILLS=(bug debugging defining-requirements extracting-user-stories launching-preview merging-and-deploying reviewing-deliverables running-atdd-cycle session-start sim-pool skill-fix skill-gate ui-test-debugging writing-design-doc writing-plan-and-tests)
}

# --- AC1: All skills have SKILL.md ---

@test "all skill directories have SKILL.md" {
  for skill in "${ALL_SKILLS[@]}"; do
    [[ -f "skills/${skill}/SKILL.md" ]]
  done
}

@test "ALL_SKILLS matches actual skill directories" {
  actual=($(ls -d skills/*/ | xargs -n1 basename | sort))
  expected=($(printf '%s\n' "${ALL_SKILLS[@]}" | sort))
  [[ "${actual[*]}" == "${expected[*]}" ]]
}

# --- AC2: All skills have name and description in frontmatter ---

@test "all skills have name in frontmatter" {
  for skill in "${ALL_SKILLS[@]}"; do
    grep -q '^name:' "skills/${skill}/SKILL.md"
  done
}

@test "all skills have description in frontmatter" {
  for skill in "${ALL_SKILLS[@]}"; do
    grep -q '^description:' "skills/${skill}/SKILL.md"
  done
}

@test "all skills have non-empty description" {
  for skill in "${ALL_SKILLS[@]}"; do
    desc=$(grep '^description:' "skills/${skill}/SKILL.md" | sed 's/^description:[[:space:]]*//' | tr -d '"')
    [[ -n "$desc" ]]
  done
}
