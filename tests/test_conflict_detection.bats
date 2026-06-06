#!/usr/bin/env bats
# @covers: skills/session-start/SKILL.md
# AC1: session-start displays conflict status
@test "session-start queries mergeable field" {
  grep -q 'mergeable' skills/session-start/SKILL.md
}

@test "session-start mentions CONFLICTING in report format" {
  grep -q 'CONFLICTING' skills/session-start/SKILL.md
}

@test "session-start recommends rebase for conflicting PRs" {
  grep -q 'rebase' skills/session-start/SKILL.md
}
