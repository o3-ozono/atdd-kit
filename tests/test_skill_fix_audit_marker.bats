#!/usr/bin/env bats
# @covers: skills/skill-fix/SKILL.md
# AC4 手順 2: audit marker regex pinning

DISPATCH_LIB="lib/skill_fix_dispatch.sh"

setup() {
  # Minimal stub for testing
  TEST_PARENT_N=42
  TEST_CHILD_N=99
  TEST_TIMESTAMP="2026-04-21T00:00:00Z"
}

# --- Audit marker format ---

@test "AC4: audit marker regex is defined in dispatch lib" {
  grep -q 'skill-fix-audit' "$DISPATCH_LIB"
}

@test "AC4: audit marker contains parent-issue reference" {
  grep -q 'parent-issue' "$DISPATCH_LIB"
}

@test "AC4: audit marker contains ISO-8601 timestamp placeholder" {
  grep -qE 'ISO-8601|timestamp|date.*T.*Z' "$DISPATCH_LIB"
}

@test "AC4: audit marker is HTML comment format" {
  grep -q '<!--.*skill-fix-audit.*-->' "$DISPATCH_LIB"
}

# --- Audit marker regex pinning: validate correct format ---

@test "AC4: audit marker matches expected regex" {
  # Generate a sample marker and verify it matches the regex
  marker="<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #${TEST_PARENT_N} at ${TEST_TIMESTAMP} -->"
  regex='^<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #[0-9]+ at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z -->$'
  [[ "$marker" =~ $regex ]]
}

@test "AC4: audit marker without parent-issue number does NOT match regex" {
  marker="<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #abc at ${TEST_TIMESTAMP} -->"
  regex='^<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #[0-9]+ at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z -->$'
  ! [[ "$marker" =~ $regex ]]
}

@test "AC4: audit marker with invalid timestamp does NOT match regex" {
  marker="<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #42 at 2026/04/21 -->"
  regex='^<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #[0-9]+ at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z -->$'
  ! [[ "$marker" =~ $regex ]]
}
