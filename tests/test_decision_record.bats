#!/usr/bin/env bats

# Issue #13: Decision Record generation
# Tests for AC1-AC7

setup() {
  ALL_SKILLS=(atdd bug debugging discover ideate issue plan record session-start ship sim-pool skill-gate ui-test-debugging verify)
}

# --- AC2: discover/plan post Discussion Summary ---

@test "AC2: discover SKILL.md has Discussion Summary in deliverables format" {
  grep -q '### Discussion Summary' skills/discover/SKILL.md
}

@test "AC2: discover SKILL.md Discussion Summary is in the posting template" {
  # Discussion Summary must appear in the gh issue comment template section
  grep -A5 'Discussion Summary' skills/discover/SKILL.md | grep -qi 'approach\|verdict\|rationale\|rejected\|選択'
}

@test "AC2: plan SKILL.md has Discussion Summary in deliverables format" {
  grep -q '### Discussion Summary' skills/plan/SKILL.md
}

@test "AC2: plan SKILL.md Discussion Summary is in the posting template" {
  grep -A5 'Discussion Summary' skills/plan/SKILL.md | grep -qi 'decision\|rationale\|trade.*off\|選択'
}

# --- AC3: Decision Record file generation ---

@test "AC3: record skill directory exists with SKILL.md" {
  [[ -f "skills/record/SKILL.md" ]]
}

@test "AC3: record SKILL.md has required sections" {
  grep -q '## Background\|### Background' skills/record/SKILL.md
  grep -q 'Discussion Summary' skills/record/SKILL.md
  grep -q 'User Story' skills/record/SKILL.md
  grep -q 'Acceptance Criteria' skills/record/SKILL.md
  grep -q 'Implementation Plan\|Test Plan' skills/record/SKILL.md
  grep -q 'Changes\|方針変更' skills/record/SKILL.md
}

@test "AC3: record SKILL.md reads Issue comments via gh" {
  grep -q 'gh issue view' skills/record/SKILL.md
}

@test "AC3: record SKILL.md reads PR body" {
  grep -q 'gh pr' skills/record/SKILL.md
}

@test "AC3: record SKILL.md outputs to docs/decisions/" {
  grep -q 'docs/decisions/' skills/record/SKILL.md
}

# --- AC4: File naming convention ---

@test "AC4: record SKILL.md specifies YYYY-MM-DD naming" {
  grep -q 'YYYY-MM-DD' skills/record/SKILL.md
}

@test "AC4: record SKILL.md specifies slug generation from Issue title" {
  grep -qi 'slug' skills/record/SKILL.md
}

# --- AC5: Implementation details excluded ---

@test "AC5: record SKILL.md has exclusion rule for implementation details" {
  grep -qi 'exclude\|除外\|not include\|含まない\|omit' skills/record/SKILL.md
  grep -qi 'code snippet\|diff\|implementation detail\|実装.*詳細\|コードスニペット' skills/record/SKILL.md
}

# --- AC6: Mid-course corrections ---

@test "AC6: record SKILL.md has Changes section for mid-course corrections" {
  grep -qi 'changes\|correction\|方針変更\|mid-course\|direction change' skills/record/SKILL.md
}

# --- AC7: Fallback for missing Discussion Summary ---

@test "AC7: record SKILL.md has fallback for missing Discussion Summary" {
  grep -qi 'no discussion summary\|fallback\|missing\|not found\|存在しない' skills/record/SKILL.md
}

# --- AC1: Ship -> Record chain ---

@test "AC1: ship SKILL.md chains to record skill after merge" {
  grep -qi 'record' skills/ship/SKILL.md
}

@test "AC1: ship SKILL.md invokes record via Skill tool" {
  grep -qi 'atdd-kit:record\|invoke.*record\|record.*skill' skills/ship/SKILL.md
}

# --- Structural: record skill in ALL_SKILLS ---

@test "ALL_SKILLS matches actual skill directories (including record)" {
  actual=($(ls -d skills/*/ | xargs -n1 basename | sort))
  expected=($(printf '%s\n' "${ALL_SKILLS[@]}" | sort))
  [[ "${actual[*]}" == "${expected[*]}" ]]
}

@test "record skill has name in frontmatter" {
  grep -q '^name:' skills/record/SKILL.md
}

@test "record skill has description in frontmatter" {
  grep -q '^description:' skills/record/SKILL.md
}
