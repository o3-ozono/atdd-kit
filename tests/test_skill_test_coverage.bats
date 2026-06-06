#!/usr/bin/env bats
# @covers: tests/
# Coverage Unit Test (#196 / #179 Step C1).
# Mechanically verifies that every v1.0-flow skill has BOTH a Unit Test
# (tests/test_<skill>_skill.bats) and a Skill E2E Test (tests/e2e/<skill>.bats).
#
# This is the final proof for the #179 DoD: "all 10 flow-target skills have a
# Unit Test + Skill E2E Test implemented and green."
#
# Per `docs/guides/testing-skills.md` (#222):
#   - Unit Test  : tests/test_<skill>_skill.bats  (hyphens → underscores, _skill suffix)
#   - Skill E2E  : tests/e2e/<skill>.bats          (skill name verbatim)

setup() {
  # The 10 flow-target skills (6 chain + 2 on-demand + 2 special).
  FLOW_SKILLS=(
    defining-requirements
    extracting-user-stories
    writing-plan-and-tests
    running-atdd-cycle
    reviewing-deliverables
    merging-and-deploying
    launching-preview
    writing-design-doc
    bug
    debugging
  )
}

_unit_file() {
  # hyphen → underscore, prefix test_, suffix _skill.bats
  local skill="$1"
  echo "tests/test_${skill//-/_}_skill.bats"
}

_e2e_file() {
  local skill="$1"
  echo "tests/e2e/${skill}.bats"
}

@test "coverage: exactly 10 flow-target skills are tracked" {
  [ "${#FLOW_SKILLS[@]}" -eq 10 ]
}

@test "coverage: every flow skill has a Unit Test (tests/test_<skill>_skill.bats)" {
  local missing=()
  for skill in "${FLOW_SKILLS[@]}"; do
    local f
    f="$(_unit_file "$skill")"
    [ -f "$f" ] || missing+=("$f")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    printf 'Missing Unit Tests:\n'
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "coverage: every flow skill has a Skill E2E Test (tests/e2e/<skill>.bats)" {
  local missing=()
  for skill in "${FLOW_SKILLS[@]}"; do
    local f
    f="$(_e2e_file "$skill")"
    [ -f "$f" ] || missing+=("$f")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    printf 'Missing Skill E2E Tests:\n'
    printf '  %s\n' "${missing[@]}"
    return 1
  fi
}

@test "coverage: each flow skill has a corresponding skills/<skill>/SKILL.md" {
  for skill in "${FLOW_SKILLS[@]}"; do
    [ -f "skills/${skill}/SKILL.md" ]
  done
}
