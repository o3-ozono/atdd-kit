#!/usr/bin/env bats
# @covers: addons/discord/**
# =============================================================================
# Discord notifications addon — isolation & opt-in policy (#318)
#
# 旧 #169 の「Discord 全面削除」ポリシーを置換する。状況が変わり Discord は許容
# されるが、**opt-in の隔離 addon** に限る:
#   - Discord 固有コードは addons/discord/ にのみ存在（core lib/・templates/ は
#     サービス非依存の汎用 FA_NOTIFY_CMD フックのみ）。
#   - 自動有効化しない。session-start が明示 [y/N]（既定 N）で尋ねたときだけ有効化。
# =============================================================================

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
EXCLUDE="--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=worktrees --exclude-dir=.tmp"

@test "DA-1: notifier lives in the addon, not in core lib/" {
  [ -f "$REPO_ROOT/addons/discord/scripts/fa-notify-discord.sh" ]
  [ ! -f "$REPO_ROOT/lib/fa-notify-discord.sh" ]
}

@test "DA-2: core lib/ is discord-free (service-agnostic FA_NOTIFY_CMD only)" {
  run grep -rli discord "$REPO_ROOT/lib" $EXCLUDE
  [ "$status" -ne 0 ]
}

@test "DA-3: templates/ is discord-free" {
  run grep -rli discord "$REPO_ROOT/templates" $EXCLUDE
  [ "$status" -ne 0 ]
}

@test "DA-4: addon is opt-in (opt_in: true, no auto-detect block)" {
  grep -q 'opt_in:[[:space:]]*true' "$REPO_ROOT/addons/discord/addon.yml"
  run grep -qE '^detect:' "$REPO_ROOT/addons/discord/addon.yml"
  [ "$status" -ne 0 ]
}

@test "DA-5: session-start asks explicit opt-in (default N) before enabling" {
  grep -qi 'Enable Discord notifications addon' "$REPO_ROOT/skills/session-start/SKILL.md"
  grep -q '\[y/N\]' "$REPO_ROOT/skills/session-start/SKILL.md"
}

@test "DA-6: a dedicated opt-in setup command exists" {
  [ -f "$REPO_ROOT/commands/setup-discord.md" ]
}

@test "DA-7: old removed implementation paths stay absent" {
  [ ! -f "$REPO_ROOT/scripts/discord-thread.sh" ]
  [ ! -f "$REPO_ROOT/tests/test_discord_thread.bats" ]
  [ ! -f "$REPO_ROOT/docs/discord-integration.md" ]
}
