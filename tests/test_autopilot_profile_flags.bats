#!/usr/bin/env bats

# Issue #122 — Flagless (default) profile drift-detect.
#
# Scope:
#   AC1 — custom defined + no flag → custom applied, partial-definition roles
#         fall back to session default (Agent tool model omitted)
#   AC2 — custom absent + no flag → all roles inherit session default
#
# Strategy: drift-detect on commands/autopilot.md — the spec must describe the
# flagless path branching on `.claude/config.yml` `spawn_profiles.custom`
# presence, and must explicitly call out the partial-definition fallback.

AUTOPILOT="${BATS_TEST_DIRNAME}/../commands/autopilot.md"

@test "autopilot.md exists" {
  [ -f "$AUTOPILOT" ]
}

# --- AC1: custom defined, no flag → custom applied (partial-definition) ---

@test "AC1: autopilot.md documents .claude/config.yml spawn_profiles.custom" {
  grep -q 'spawn_profiles.custom' "$AUTOPILOT"
}

@test "AC1: autopilot.md references .claude/config.yml as model source" {
  grep -qE '\.claude/config\.yml' "$AUTOPILOT"
}

@test "AC1: autopilot.md documents partial-definition fallback to session default" {
  # When custom defines only some roles, unmentioned roles must fall back to
  # session default (model parameter omitted).
  grep -qiE 'partial.*definition|undefined role.*session default|roles not.*custom.*session default|custom に無い role|未定義 role|omit.*model.*session default' "$AUTOPILOT"
}

@test "AC1: flagless path does not fire the Profile Confirmation Gate" {
  grep -qiE 'no profile flag.*no.*gate|gate.*skipped.*no.*flag|flagless.*skip.*gate|no.*profile flag.*nothing to confirm|Gate.*(only|limited).*--profile' "$AUTOPILOT"
}

# --- AC2: custom absent, no flag → session default ---

@test "AC2: autopilot.md documents custom-absent + no-flag session default inheritance" {
  grep -qiE 'custom absent.*session default|no.*custom.*session default|spawn_profiles.custom.*absent.*session default|config\.yml.*absent.*session default' "$AUTOPILOT"
}

@test "AC2: autopilot.md documents model parameter omission under flagless + custom-absent" {
  grep -qiE 'omit.*model.*parameter|model.*parameter.*omit|Agent tool call omits the model' "$AUTOPILOT"
}

# --- Single source of truth & removal of legacy preset flags ---

@test "removal: autopilot.md no longer references config/spawn-profiles.yml" {
  ! grep -q 'config/spawn-profiles.yml' "$AUTOPILOT"
}

@test "removal: Usage section does not advertise --light / --heavy" {
  usage=$(awk '/^## Usage/{in_block=1; next} in_block && /^## /{exit} in_block{print}' "$AUTOPILOT")
  [ -n "$usage" ]
  ! echo "$usage" | grep -qE -e '--light'
  ! echo "$usage" | grep -qE -e '--heavy'
}

@test "AC1/AC2: Agent spawn model resolution block references .claude/config.yml custom" {
  awk '/^### Agent spawn model resolution/{in_block=1; next} in_block && /^## /{exit} in_block && /^### /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/spawn_resolution.txt
  grep -qE 'spawn_profiles\.custom|\.claude/config\.yml' /tmp/spawn_resolution.txt
}

# --- Role coverage in custom spec section ---

@test "AC1: autopilot.md references all 6 roles in custom-applied spec" {
  awk '/^### Agent spawn model resolution/{in_block=1; next} in_block && /^## /{exit} in_block && /^### /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/spawn_resolution.txt
  # Each role name must be present either in the resolution block or visible
  # elsewhere in the autopilot spec (AC1 partial-definition path lists them).
  for role in developer qa tester reviewer researcher writer; do
    grep -q "$role" "$AUTOPILOT" \
      || { echo "role missing from autopilot.md: $role"; return 1; }
  done
}
