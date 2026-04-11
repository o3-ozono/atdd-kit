#!/usr/bin/env bats

# Issue #169: Notification integration removal tests
# Verifies all external notification code, docs, config, and tests are removed.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Exclude patterns for repo-wide grep (worktrees are separate checkouts)
EXCLUDE_DIRS="--exclude-dir=.git --exclude-dir=.tmp --exclude-dir=node_modules --exclude-dir=worktrees --exclude-dir=decisions"

# --- AC1: Dedicated notification files must not exist ---

@test "AC1: docs/discord-integration.md does not exist" {
  [ ! -f "$REPO_ROOT/docs/discord-integration.md" ]
}

@test "AC1: scripts/discord-thread.sh does not exist" {
  [ ! -f "$REPO_ROOT/scripts/discord-thread.sh" ]
}

@test "AC1: test_discord_push.bats does not exist" {
  [ ! -f "$REPO_ROOT/tests/test_discord_push.bats" ]
}

@test "AC1: test_discord_thread.bats does not exist" {
  [ ! -f "$REPO_ROOT/tests/test_discord_thread.bats" ]
}

@test "AC1: test_discord_channels.bats does not exist" {
  [ ! -f "$REPO_ROOT/tests/test_discord_channels.bats" ]
}

@test "AC1: test_discord_warning_skip.bats does not exist" {
  [ ! -f "$REPO_ROOT/tests/test_discord_warning_skip.bats" ]
}

@test "AC1: test_init_discord_enabledplugins.bats does not exist" {
  [ ! -f "$REPO_ROOT/tests/test_init_discord_enabledplugins.bats" ]
}

# --- AC2: Skill files have no notification service references ---

@test "AC2: discover/SKILL.md has no notification service references" {
  ! grep -qi "discord" "$REPO_ROOT/skills/discover/SKILL.md"
}

@test "AC2: plan/SKILL.md has no notification service references" {
  ! grep -qi "discord" "$REPO_ROOT/skills/plan/SKILL.md"
}

@test "AC2: atdd/SKILL.md has no notification service references" {
  ! grep -qi "discord" "$REPO_ROOT/skills/atdd/SKILL.md"
}

@test "AC2: session-start/SKILL.md has no notification service references" {
  ! grep -qi "discord" "$REPO_ROOT/skills/session-start/SKILL.md"
}

# --- AC3: Commands, templates, config have no notification service references ---

@test "AC3: commands/autopilot.md has no notification service references" {
  ! grep -qi "discord" "$REPO_ROOT/commands/autopilot.md"
}

@test "AC3: commands/auto-sweep.md has no notification service references" {
  ! grep -qi "discord" "$REPO_ROOT/commands/auto-sweep.md"
}

@test "AC3: workflow-config template no longer exists" {
  [[ ! -f "$REPO_ROOT/templates/workflow-config.yml.tmpl" ]]
}

@test "AC3: .claude/workflow-config.yml has no notification section" {
  ! grep -qi "discord" "$REPO_ROOT/.claude/workflow-config.yml"
}

@test "AC3: scripts/start-session.sh has no notification service references" {
  ! grep -qi "discord" "$REPO_ROOT/scripts/start-session.sh"
}

# --- AC5: Zero notification service references repo-wide (excluding CHANGELOG and worktrees) ---

@test "AC5: no notification service references in .md files (excluding CHANGELOG)" {
  local count
  count=$(grep -rli "discord" "$REPO_ROOT" \
    --include="*.md" \
    --exclude="CHANGELOG.md" \
    $EXCLUDE_DIRS | wc -l)
  [ "$count" -eq 0 ]
}

@test "AC5: no notification service references in .yml files" {
  local count
  count=$(grep -rli "discord" "$REPO_ROOT" \
    --include="*.yml" \
    $EXCLUDE_DIRS | wc -l)
  [ "$count" -eq 0 ]
}

@test "AC5: no notification service references in .sh files" {
  local count
  count=$(grep -rli "discord" "$REPO_ROOT" \
    --include="*.sh" \
    $EXCLUDE_DIRS | wc -l)
  [ "$count" -eq 0 ]
}

@test "AC5: no notification service references in .bats files" {
  local count
  count=$(grep -rli "discord" "$REPO_ROOT" \
    --include="*.bats" \
    --exclude="test_notification_removal.bats" \
    $EXCLUDE_DIRS | wc -l)
  [ "$count" -eq 0 ]
}
