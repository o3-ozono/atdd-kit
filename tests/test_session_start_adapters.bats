#!/usr/bin/env bats

# skill_adapters validation removed from session-start.
# Agent configuration is now in agents/*.md files.

@test "session-start does not have skill_adapters validation phase" {
  ! grep -q 'skill_adapters.*[Vv]alidat' skills/session-start/SKILL.md
}

@test "session-start does not block on invalid skill_adapters" {
  ! grep -qi 'skill_adapters.*block\|skill_adapters.*STOP' skills/session-start/SKILL.md
}

@test "session-start does not reference skill_adapters at all" {
  ! grep -q 'skill_adapters' skills/session-start/SKILL.md
}
