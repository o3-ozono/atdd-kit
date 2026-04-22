#!/usr/bin/env bats
# @covers: skills/session-start/SKILL.md
# session-start SKILL.md に Recent Activity (24h) の記述があることを検証

@test "session-start has recent activity gathering step" {
  grep -q 'Recent Activity' skills/session-start/SKILL.md
}

@test "session-start fetches merged PRs in recent activity" {
  # Phase 1 の Recent Activity セクション内で merged PR を取得
  sed -n '/Recent Activity/,/^### / p' skills/session-start/SKILL.md | grep -q 'gh pr list.*--state merged'
}

@test "session-start fetches closed Issues" {
  grep -q 'gh issue list.*closed' skills/session-start/SKILL.md
}

@test "session-start skips recent activity section when empty" {
  grep -qi 'recent activity.*skip\|skip.*recent activity\|no recent activity\|both results are empty' skills/session-start/SKILL.md
}

@test "session-start recent activity section in Phase 3 report" {
  # Recent Activity が Phase 3 レポートテンプレート内にある
  sed -n '/Phase 3/,$ p' skills/session-start/SKILL.md | grep -q 'Recent Activity'
}
