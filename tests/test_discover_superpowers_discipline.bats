#!/usr/bin/env bats
# @covers: skills/discover/SKILL.md
# Issue #138: discover skill superpowers discipline — Rationalization table, HARD-GATE
# single-block, Terminal-state clause

DISCOVER="skills/discover/SKILL.md"

@test "AC4(i): Rationalization table header exists" {
  grep -q "| Excuse | Reality |" "$DISCOVER"
}

@test "AC4(ii): HARD-GATE block appears exactly once" {
  count=$(grep -c "^<HARD-GATE>" "$DISCOVER")
  [ "$count" -eq 1 ]
}

@test "AC4(iii): Terminal-state clause restricts next invocation to atdd-kit:plan only" {
  grep -q "atdd-kit:plan" "$DISCOVER"
  grep -qE "(only.*atdd-kit:plan|atdd-kit:plan.*only|その他禁止|no other skills)" "$DISCOVER"
}
