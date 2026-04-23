#!/usr/bin/env bats
# @covers: skills/atdd/SKILL.md
# Issue #140: atdd skill superpowers discipline — Rationalization table, HARD-GATE
# single-block, Terminal-state clause

ATDD="skills/atdd/SKILL.md"

@test "AC4(i): Rationalization table header exists" {
  grep -q "| Excuse | Reality |" "$ATDD"
}

@test "AC4(ii): HARD-GATE block appears exactly once" {
  count=$(grep -c "^<HARD-GATE>" "$ATDD")
  [ "$count" -eq 1 ]
}

@test "AC4(iii): Terminal-state clause restricts next invocation to atdd-kit:verify only" {
  grep -q "atdd-kit:verify" "$ATDD"
  grep -iE "(only.*atdd-kit:verify|atdd-kit:verify.*only|no other skills)" "$ATDD"
}
