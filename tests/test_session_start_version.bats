#!/usr/bin/env bats
# @covers: skills/session-start/SKILL.md
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

# AC6 #75: session-start report shows concise notification
@test "AC6 #75: SKILL.md Phase 1-E parses VERSIONS count from UPDATED output" {
  grep -q 'VERSIONS' skills/session-start/SKILL.md
}

@test "AC6 #75: SKILL.md Phase 1-E parses BREAKING count from UPDATED output" {
  grep -q 'BREAKING' skills/session-start/SKILL.md
}

@test "AC6 #75: SKILL.md Phase 3 report template shows v<old> to v<new> format" {
  grep -q 'v<old>.*v<new>' skills/session-start/SKILL.md
}

@test "AC6 #75: SKILL.md Phase 3 report template shows versions count and breaking changes" {
  grep -q 'versions.*breaking changes\|breaking changes.*versions' skills/session-start/SKILL.md
}

@test "AC6 #75: SKILL.md Phase 3 report template includes CHANGELOG.md reference" {
  grep -q 'See CHANGELOG.md for details' skills/session-start/SKILL.md
}

@test "AC6 #75: SKILL.md Phase 3 report template does not include raw CHANGELOG diff placeholder" {
  # Old format: "> (CHANGELOG diff here)" should no longer be present
  run grep -c 'CHANGELOG diff here' skills/session-start/SKILL.md
  [[ "$output" == "0" ]]
}
