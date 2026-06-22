#!/usr/bin/env bats
# @covers: skills/batch-discovery/SKILL.md docs/methodology/autopilot-iron-law.md
# AT-341-F: deterministic bats AT で AL-1 三ゲート整合の不変条件を検証する（CS-3）
# Issue #341
#
# Verifies that SKILL.md and autopilot-iron-law.md are consistently aligned:
#   - batch-discovery Gate ① = cross-Issue batched 壁打ち (1 session)
#   - batch-discovery Gate ② equivalent = selective final approval (max 1 session)
#   - Gate ③ merge = full-autopilot merge coordinator (unchanged)
#   - AC approval gate (false-green external anchor) is not removed
#
# All assertions are structural string checks — deterministic, network-independent.
#
# lifecycle: [regression]

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

setup() {
  REPO="$(repo_root)"
  SKILL="${REPO}/skills/batch-discovery/SKILL.md"
  IRON_LAW="${REPO}/docs/methodology/autopilot-iron-law.md"
}

# ---------------------------------------------------------------------------
# AT-341-F1: batch-discovery SKILL.md ← AL-1 三ゲート整合
# ---------------------------------------------------------------------------

@test "AT-341-F1: SKILL.md defines Gate1 as cross-Issue batched requirements session" {
  grep -qiE 'Gate.*batch|Gate.*①|batch.*Gate|Gate.*1.*batch' "$SKILL"
}

@test "AT-341-F1: SKILL.md defines Gate2-equivalent as selective final approval (max 1)" {
  grep -qiE 'Gate.*②.*selective|selective.*Gate|Gate.*②.*final.*approv|0 or 1' "$SKILL"
}

@test "AT-341-F1: SKILL.md defines Gate3 as full-autopilot merge coordinator (unchanged)" {
  grep -qiE 'Gate.*③.*full-autopilot|full-autopilot.*Gate.*③' "$SKILL"
}

@test "AT-341-F1: SKILL.md states AC approval gate (false-green anchor) is not removed" {
  grep -qiE 'not.*remov.*gate|gate.*not.*remov|AC.*approv.*gate|false-green' "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-341-F1: autopilot-iron-law.md documents AL-1 under full-autopilot (Gate③ unchanged)
# ---------------------------------------------------------------------------

@test "AT-341-F1: autopilot-iron-law.md AL-1 section exists" {
  test -f "$IRON_LAW"
  grep -q 'AL-1' "$IRON_LAW"
}

@test "AT-341-F1: autopilot-iron-law.md states three user gates are fixed" {
  grep -qiE 'Three User gates|three.*gate.*fixed|Three.*gate' "$IRON_LAW"
}

@test "AT-341-F1: autopilot-iron-law.md states Gate3 merge uses merge coordinator" {
  grep -qiE 'merge coordinator|merge.*coordinator' "$IRON_LAW"
}

# ---------------------------------------------------------------------------
# AT-341-F1: skills/README.md and CHANGELOG list batch-discovery (finishing invariants)
# ---------------------------------------------------------------------------

@test "AT-341-F1: skills/README.md lists batch-discovery" {
  grep -q 'batch-discovery' "${REPO}/skills/README.md"
}

@test "AT-341-F1: CHANGELOG.md contains #341 batch-discovery entry" {
  grep -q '#341' "${REPO}/CHANGELOG.md"
}

@test "AT-341-F1: plugin.json version matches topmost CHANGELOG release heading (no exact-version pin)" {
  local plugin_ver changelog_ver
  plugin_ver=$(jq -r '.version' "${REPO}/.claude-plugin/plugin.json")
  changelog_ver=$(grep -E '^## \[[0-9]' "${REPO}/CHANGELOG.md" | head -1 | sed 's/## \[//;s/\].*//')
  [ "$plugin_ver" = "$changelog_ver" ]
}
