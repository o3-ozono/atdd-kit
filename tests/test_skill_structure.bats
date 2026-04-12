#!/usr/bin/env bats

# Skill lists for structure validation
setup() {
  ALL_SKILLS=(atdd bug debugging discover ideate issue plan record session-start ship sim-pool skill-gate ui-test-debugging verify)
  # Skills with approval gates (discover, plan, ideate)
  # bug and issue are intake skills that chain to discover for approval
  APPROVAL_GATE_SKILLS=(discover plan ideate)
  # Skills that post deliverables via gh issue comment
  ISSUE_COMMENT_SKILLS=(discover plan)
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

# --- AC3: Interactive skills have approval gate description ---

@test "approval gate skills have approval description" {
  for skill in "${APPROVAL_GATE_SKILLS[@]}"; do
    grep -qi 'approv' "skills/${skill}/SKILL.md"
  done
}

# --- AC4: Skills with deliverables have gh issue comment instruction ---

@test "deliverable skills have gh issue comment instruction" {
  for skill in "${ISSUE_COMMENT_SKILLS[@]}"; do
    grep -q 'gh issue comment' "skills/${skill}/SKILL.md"
  done
}

# --- AC5: discover skill has required check sections ---

@test "discover has UX check section (U1-U5)" {
  grep -q 'U1' skills/discover/SKILL.md
  grep -q 'U2' skills/discover/SKILL.md
  grep -q 'U3' skills/discover/SKILL.md
  grep -q 'U4' skills/discover/SKILL.md
  grep -q 'U5' skills/discover/SKILL.md
}

@test "discover has interruption scenario check section (I1-I4)" {
  grep -q 'I1' skills/discover/SKILL.md
  grep -q 'I2' skills/discover/SKILL.md
  grep -q 'I3' skills/discover/SKILL.md
  grep -q 'I4' skills/discover/SKILL.md
}

@test "discover has Given/When/Then format specification" {
  grep -q 'Given' skills/discover/SKILL.md
  grep -q 'When' skills/discover/SKILL.md
  grep -q 'Then' skills/discover/SKILL.md
}
