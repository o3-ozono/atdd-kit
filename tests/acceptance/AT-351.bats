#!/usr/bin/env bats
# @covers: commands/bugfix.md commands/README.md skills/README.md skills/skill-gate/SKILL.md skills/fixing-bugs/SKILL.md docs/methodology/route-eligibility.md tests/README.md tests/acceptance/AT-308.bats
# AT-351: command rename /atdd-kit:autofix -> /atdd-kit:bugfix
# Issue #351
#
# Asserts invariants (no exact-version/date/line-count pin, #289).
# Historical records excluded from grep:
#   docs/issues/308-*, docs/issues/322-*, docs/issues/246-*,
#   docs/issues/351-* prd/user-stories, CHANGELOG.md #308 entry.
#
# lifecycle: [green]

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

setup() {
  REPO="$(repo_root)"
}

# ---------------------------------------------------------------------------
# AT-351-1: bugfix command wired to fixing-bugs route (F1 / C1)
# ---------------------------------------------------------------------------

@test "AT-351-1: commands/bugfix.md exists" {
  test -f "${REPO}/commands/bugfix.md"
}

@test "AT-351-1: commands/autofix.md does not exist" {
  ! test -f "${REPO}/commands/autofix.md"
}

@test "AT-351-1: commands/bugfix.md contains fixing-bugs wiring" {
  grep -q 'fixing-bugs' "${REPO}/commands/bugfix.md"
}

@test "AT-351-1: commands/bugfix.md contains issue-number argument" {
  grep -qE '<issue-number>' "${REPO}/commands/bugfix.md"
}

@test "AT-351-1: commands/bugfix.md contains /atdd-kit:bugfix notation" {
  grep -q '/atdd-kit:bugfix' "${REPO}/commands/bugfix.md"
}

@test "AT-351-1: commands/bugfix.md has no /atdd-kit:autofix notation (no alias stub)" {
  local count
  count=$(grep -c '/atdd-kit:autofix' "${REPO}/commands/bugfix.md" || true)
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AT-351-2: autofix references removed from live documentation (F2)
# ---------------------------------------------------------------------------

@test "AT-351-2: commands/README.md has no autofix string" {
  local count
  count=$(grep -c autofix "${REPO}/commands/README.md" || true)
  [ "$count" -eq 0 ]
}

@test "AT-351-2: commands/README.md contains link to bugfix.md" {
  grep -q 'bugfix.md' "${REPO}/commands/README.md"
}

@test "AT-351-2: skills/README.md has no autofix string" {
  local count
  count=$(grep -c autofix "${REPO}/skills/README.md" || true)
  [ "$count" -eq 0 ]
}

@test "AT-351-2: skills/skill-gate/SKILL.md has no autofix string" {
  local count
  count=$(grep -c autofix "${REPO}/skills/skill-gate/SKILL.md" || true)
  [ "$count" -eq 0 ]
}

@test "AT-351-2: skills/fixing-bugs/SKILL.md has no autofix string" {
  local count
  count=$(grep -c autofix "${REPO}/skills/fixing-bugs/SKILL.md" || true)
  [ "$count" -eq 0 ]
}

@test "AT-351-2: docs/methodology/route-eligibility.md has no /atdd-kit:autofix" {
  local count
  count=$(grep -c 'atdd-kit:autofix' "${REPO}/docs/methodology/route-eligibility.md" || true)
  [ "$count" -eq 0 ]
}

@test "AT-351-2: tests/README.md has no autofix string" {
  local count
  count=$(grep -c autofix "${REPO}/tests/README.md" || true)
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AT-351-3: AT-308 wiring pins updated to new command name (F3)
# ---------------------------------------------------------------------------

@test "AT-351-3: tests/acceptance/AT-308.bats has no autofix string" {
  local count
  count=$(grep -c autofix "${REPO}/tests/acceptance/AT-308.bats" || true)
  [ "$count" -eq 0 ]
}

@test "AT-351-3: tests/acceptance/AT-308.bats references commands/bugfix.md in path variable" {
  grep -q 'commands/bugfix.md' "${REPO}/tests/acceptance/AT-308.bats"
}

@test "AT-351-3: tests/acceptance/AT-308.bats greps for /atdd-kit:bugfix" {
  grep -q '/atdd-kit:bugfix' "${REPO}/tests/acceptance/AT-308.bats"
}

# ---------------------------------------------------------------------------
# AT-351-4: bugfix route behavior unchanged - static invariant pins (C3)
# ---------------------------------------------------------------------------

@test "AT-351-4: fixing-bugs SKILL.md documents the 5-skill chain order" {
  grep -q 'bug' "${REPO}/skills/fixing-bugs/SKILL.md"
  grep -q 'debugging' "${REPO}/skills/fixing-bugs/SKILL.md"
  grep -q 'running-atdd-cycle' "${REPO}/skills/fixing-bugs/SKILL.md"
  grep -q 'reviewing-deliverables' "${REPO}/skills/fixing-bugs/SKILL.md"
  grep -q 'merging-and-deploying' "${REPO}/skills/fixing-bugs/SKILL.md"
}

@test "AT-351-4: cause-agreement middle gate description is preserved" {
  grep -qF 'cause-agreement' "${REPO}/skills/fixing-bugs/SKILL.md"
}

@test "AT-351-4: User merge gate description is preserved" {
  grep -qiE 'User merge gate|merge.*User gate' "${REPO}/skills/fixing-bugs/SKILL.md"
}

# ---------------------------------------------------------------------------
# AT-351-5: version/CHANGELOG consistency (invariant / Finishing)
# ---------------------------------------------------------------------------

@test "AT-351-5: CHANGELOG.md contains a #351 rename entry" {
  grep -q '#351' "${REPO}/CHANGELOG.md"
}

@test "AT-351-5: plugin.json version matches CHANGELOG latest release heading (invariant, no exact-version pin)" {
  local plugin_ver changelog_ver
  plugin_ver=$(jq -r '.version' "${REPO}/.claude-plugin/plugin.json")
  changelog_ver=$(grep -E '^## \[[0-9]' "${REPO}/CHANGELOG.md" | head -1 | sed 's/## \[//;s/\].*//')
  [ "$plugin_ver" = "$changelog_ver" ]
}
