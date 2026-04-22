#!/usr/bin/env bats
# @covers: skills/**
# AC11: Context Block information handoff between skills
# Integration -- verifies issue/bug output Context Block and discover reads it

# --- Context Block output ---

@test "AC11: issue SKILL.md has Context Block output section" {
  grep -qi 'context.*block' skills/issue/SKILL.md
}

@test "AC11: issue SKILL.md Context Block has structured fields" {
  grep -qi 'task_type\|requirements\|environment\|collected_info' skills/issue/SKILL.md
}

@test "AC11: bug SKILL.md has Context Block output section" {
  grep -qi 'context.*block' skills/bug/SKILL.md
}

@test "AC11: bug SKILL.md Context Block has structured fields" {
  grep -qi 'task_type\|symptom\|environment\|reproduction' skills/bug/SKILL.md
}

@test "AC11: ideate SKILL.md has Context Block output for issue chain" {
  grep -qi 'context.*block' skills/ideate/SKILL.md
}

# --- Context Block reading ---

@test "AC11: discover SKILL.md reads Context Block from Issue comments" {
  grep -qi 'context.*block' skills/discover/SKILL.md
}

@test "AC11: discover SKILL.md skips redundant questions when Context Block exists" {
  grep -qi 'skip.*redundant\|skip.*duplicate\|重複.*スキップ\|already.*collected\|Context Block.*read' skills/discover/SKILL.md
}
