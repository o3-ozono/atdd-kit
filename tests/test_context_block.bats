#!/usr/bin/env bats
# @covers: skills/**
# AC11: Context Block information handoff between skills
# Integration -- verifies issue/bug output Context Block and discover reads it

# --- Context Block output ---

@test "AC11: bug SKILL.md has Context Block output section" {
  grep -qi 'context.*block' skills/bug/SKILL.md
}

@test "AC11: bug SKILL.md Context Block has structured fields" {
  grep -qi 'task_type\|symptom\|environment\|reproduction' skills/bug/SKILL.md
}
