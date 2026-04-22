#!/usr/bin/env bats
# @covers: commands/autopilot.md
# Issue #122 — .claude/config.yml SSoT & drift-detect.
#
# Scope:
#   AC8  — YAML / schema error halt in autopilot.md
#   AC9  — SSoT integrity: no config/spawn-profiles.yml file, no --light/--heavy
#          spec in autopilot.md, .claude/config.yml referenced, fixtures
#          rewritten to custom-base semantics
#   AC12 — README.md or DEVELOPMENT.md contains spawn-profile setup section
#          whose role list matches the placeholder template

REPO_ROOT="${BATS_TEST_DIRNAME}/.."
AUTOPILOT="${REPO_ROOT}/commands/autopilot.md"
README="${REPO_ROOT}/README.md"
DEVELOPMENT="${REPO_ROOT}/DEVELOPMENT.md"
NL_FIXTURES="${REPO_ROOT}/docs/tests/nl-profile-fixtures.md"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"

# --- AC8: config.yml format / schema error halt ---

@test "AC8: autopilot.md specifies .claude/config.yml halt on format error" {
  grep -qE '\.claude/config\.yml:' "$AUTOPILOT"
}

@test "AC8: autopilot.md halt on schema error names spawn_profiles.custom map shape" {
  # The halt text must mention that each role must be a map of { model: <enum> }.
  grep -qiE 'schema|map|{ *model *:' "$AUTOPILOT"
}

@test "AC8: autopilot.md config-error halt occurs before Team / worktree creation" {
  grep -qiE 'No Team.*worktree.*created|Team.*not created|halt.*before Phase 0\.9' "$AUTOPILOT"
}

# --- AC9: SSoT integrity ---

@test "AC9: legacy config/spawn-profiles.yml file does not exist" {
  [ ! -f "${REPO_ROOT}/config/spawn-profiles.yml" ]
}

@test "AC9: autopilot.md contains no --heavy spec record (excluding Unknown-flag halt literal)" {
  # The halt-text literal `Unknown flag: --heavy ...` is allowed; any other
  # reference to --heavy as a supported flag is not. Strip the halt line and
  # require nothing else.
  count=$(grep -cE -e '--heavy' "$AUTOPILOT" || true)
  halt_count=$(grep -cE 'Unknown flag: --heavy' "$AUTOPILOT" || true)
  [ "$count" -eq "$halt_count" ] \
    || { echo "--heavy referenced outside the Unknown-flag halt line ($count total, $halt_count halt)"; grep -nE -e '--heavy' "$AUTOPILOT"; return 1; }
}

@test "AC9: autopilot.md contains no --light spec record (excluding Unknown-flag halt literal)" {
  count=$(grep -cE -e '--light' "$AUTOPILOT" || true)
  halt_count=$(grep -cE 'Unknown flag: --light' "$AUTOPILOT" || true)
  [ "$count" -eq "$halt_count" ] \
    || { echo "--light referenced outside the Unknown-flag halt line ($count total, $halt_count halt)"; grep -nE -e '--light' "$AUTOPILOT"; return 1; }
}

@test "AC9: autopilot.md references .claude/config.yml for model resolution" {
  grep -qE '\.claude/config\.yml' "$AUTOPILOT"
}

@test "AC9: nl-profile-fixtures.md rewritten to custom-base semantics" {
  [ -f "$NL_FIXTURES" ]
  # Must mention custom-base / custom overlay and must not advertise --light /
  # --heavy preset fixtures as valid inputs.
  grep -qiE 'custom.*base|custom.*overlay|spawn_profiles\.custom|custom をベース' "$NL_FIXTURES"
  ! grep -qE -e '/atdd-kit:autopilot [0-9]+ --light' "$NL_FIXTURES"
  ! grep -qE -e '/atdd-kit:autopilot [0-9]+ --heavy' "$NL_FIXTURES"
}

# --- AC12: user documentation has spawn-profile setup section ---

@test "AC12: README.md or DEVELOPMENT.md has Spawn Profile section heading" {
  grep -qE '^## Spawn Profile' "$README" \
    || grep -qE '^## Spawn Profile' "$DEVELOPMENT"
}

@test "AC12: Spawn Profile section lists all 6 roles" {
  doc="$README"
  grep -qE '^## Spawn Profile' "$doc" || doc="$DEVELOPMENT"
  awk '/^## Spawn Profile/{in_block=1; next} in_block && /^## /{exit} in_block{print}' "$doc" > /tmp/profile_section.txt
  for role in developer qa tester reviewer researcher writer; do
    grep -q "$role" /tmp/profile_section.txt \
      || { echo "role missing from Spawn Profile section: $role"; return 1; }
  done
}

@test "AC12: Spawn Profile section mentions --profile NL relation" {
  doc="$README"
  grep -qE '^## Spawn Profile' "$doc" || doc="$DEVELOPMENT"
  awk '/^## Spawn Profile/{in_block=1; next} in_block && /^## /{exit} in_block{print}' "$doc" > /tmp/profile_section.txt
  grep -qE -e '--profile' /tmp/profile_section.txt
}

@test "AC12: Spawn Profile section notes --light / --heavy BREAKING removal" {
  doc="$README"
  grep -qE '^## Spawn Profile' "$doc" || doc="$DEVELOPMENT"
  awk '/^## Spawn Profile/{in_block=1; next} in_block && /^## /{exit} in_block{print}' "$doc" > /tmp/profile_section.txt
  grep -qE -i -e 'BREAKING' /tmp/profile_section.txt
  grep -qE -e '--light|--heavy' /tmp/profile_section.txt
}

@test "AC12: Spawn Profile section notes session default inheritance for unspecified roles" {
  doc="$README"
  grep -qE '^## Spawn Profile' "$doc" || doc="$DEVELOPMENT"
  awk '/^## Spawn Profile/{in_block=1; next} in_block && /^## /{exit} in_block{print}' "$doc" > /tmp/profile_section.txt
  grep -qiE 'session default|未指定.*session default|unspecified' /tmp/profile_section.txt
}

@test "AC12: CHANGELOG contains BREAKING entry for flag removal / file rename" {
  [ -f "$CHANGELOG" ]
  # Scan the [Unreleased] section and the two most-recent versioned sections —
  # the BREAKING entry belongs to whichever is active when this PR lands.
  awk '/^## \[/{count++; if (count > 3) exit} count >= 1{print}' "$CHANGELOG" > /tmp/changelog_top.txt
  grep -qiE 'BREAKING' /tmp/changelog_top.txt
  grep -qE -e '--light|--heavy' /tmp/changelog_top.txt
  grep -qE '\.claude/config\.yml|config\.yml' /tmp/changelog_top.txt
}
