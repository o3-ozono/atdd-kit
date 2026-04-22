#!/usr/bin/env bats
# Tests for AC1: explicit git switch -c in atdd Workflow Step 2 (#90)
# @covers: skills/atdd/SKILL.md

SKILL="skills/atdd/SKILL.md"

# AC1: positive -- explicit git switch -c command is present
@test "AC1: Workflow Step 2 contains explicit git switch -c command" {
    grep -q 'git switch -c feat/<issue-number>-<slug>' "$SKILL"
}

# AC1: negative -- old ambiguous phrase is removed
@test "AC1: old ambiguous phrase 'Create branch: \`feat/<issue-number>-<slug>\`' is removed" {
    ! grep -q 'Create branch: `feat/<issue-number>-<slug>`' "$SKILL"
}

# AC1: continuation hint -- git switch (without -c) is present for existing branch case
@test "AC1: Continuation Path hint 'git switch feat/' is present in SKILL.md" {
    grep -q 'git switch feat/' "$SKILL"
}
