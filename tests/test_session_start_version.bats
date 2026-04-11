#!/usr/bin/env bats

# session-start SKILL.md にバージョンチェックの記述があることを検証

@test "session-start mentions check-plugin-version.sh" {
  grep -q 'check-plugin-version' skills/session-start/SKILL.md
}

@test "session-start includes version in report template" {
  grep -q 'Version\|version\|バージョン' skills/session-start/SKILL.md
}

@test "session-start handles FIRST_RUN output" {
  grep -q 'FIRST_RUN' skills/session-start/SKILL.md
}

@test "session-start handles UPDATED output" {
  grep -q 'UPDATED' skills/session-start/SKILL.md
}
