#!/usr/bin/env bats
# @covers: skills/session-start/SKILL.md
# session-start SKILL.md addon-based sync and always-sync tests

@test "session-start has auto-sync on update step" {
  grep -qi 'Auto-Sync\|auto.sync.*update\|Auto Sync' skills/session-start/SKILL.md
}

@test "session-start references addon.yml deploy section" {
  grep -q 'addon.yml' skills/session-start/SKILL.md
  grep -q 'deploy' skills/session-start/SKILL.md
}

@test "session-start does NOT contain hardcoded scripts/ios/ paths" {
  ! grep -q 'scripts/ios/' skills/session-start/SKILL.md
}

@test "session-start references addons/<platform> for file sync" {
  grep -q 'addons/' skills/session-start/SKILL.md
}

@test "session-start always-syncs issue templates" {
  grep -q 'templates/issue/' skills/session-start/SKILL.md
}

@test "session-start always-syncs PR template" {
  grep -q 'pull_request_template' skills/session-start/SKILL.md
}

@test "templates/issue/ directory exists for always-sync" {
  [[ -d "templates/issue" ]]
}

@test "templates/pr/ directory exists for always-sync" {
  [[ -d "templates/pr" ]]
}

@test "session-start shows sync report in Phase 3" {
  sed -n '/Phase 3/,$ p' skills/session-start/SKILL.md | grep -qi 'Plugin Sync\|Sync.*Report'
}
