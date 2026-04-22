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

# AC2: ship blocks merge and offers rebase on conflict
@test "ship checks mergeable before merge" {
  grep -q 'mergeable' skills/ship/SKILL.md
}

@test "ship mentions rebase on conflict" {
  grep -q 'rebase' skills/ship/SKILL.md
}

# AC3: autopilot PO checks mergeable and handles conflict
@test "autopilot checks mergeable before merge" {
  grep -q 'mergeable' commands/autopilot.md
}

@test "autopilot handles needs-pr-revision on conflict" {
  grep -q 'needs-pr-revision' commands/autopilot.md
}

@test "autopilot mentions CONFLICTING" {
  grep -q 'CONFLICTING' commands/autopilot.md
}

# AC4: ship red flags include conflict
@test "ship red flags include merge conflict" {
  grep -qi 'conflict' skills/ship/SKILL.md
}
