#!/usr/bin/env bats

# Issue #122 — NL profile drift-detect (custom-base + NL overlay).
#
# Scope:
#   AC3 — --profile="NL" resolves on top of spawn_profiles.custom, NL wins on
#         role collisions; roles neither in custom nor in NL → session default
#   AC4 — Profile Confirmation Gate fires ONLY when --profile is specified
#   AC6 — Unknown role / unknown model in NL halts with specific error text
#
# Strategy: drift-detect on commands/autopilot.md — the NL profile path must
# document a custom-base overlay (not a fresh resolution), the gate must be
# gated on --profile presence, and the halt text must match AC6 literal.

AUTOPILOT="${BATS_TEST_DIRNAME}/../commands/autopilot.md"

# --- AC3: --profile NL resolves on top of custom, NL wins on collision ---

@test "AC3: autopilot.md documents --profile NL overlay on custom base" {
  grep -qiE 'NL.*overlay.*custom|custom.*base.*NL|custom をベースに NL|NL が custom を上書き|NL overlay|NL over custom|NL on top of custom' "$AUTOPILOT"
}

@test "AC3: autopilot.md documents NL-wins-on-collision rule" {
  grep -qiE 'NL (wins|overrides|takes precedence|優先)|重複.*NL.*優先|collision.*NL' "$AUTOPILOT"
}

@test "AC3: autopilot.md documents session default fallback for roles unset in both custom and NL" {
  grep -qiE '(neither|nor) custom.*nor NL.*session default|roles.*not.*custom.*NL.*session default|custom にも NL.*session default|both absent.*session default' "$AUTOPILOT"
}

@test "AC3: NL Resolution Examples block still exists" {
  grep -q '<!-- nl-example start -->' "$AUTOPILOT" \
    && grep -q '<!-- nl-example end -->' "$AUTOPILOT"
}

# --- AC4: Confirmation gate fires only when --profile is specified ---

@test "AC4: Profile Confirmation Gate sub-heading exists" {
  grep -qE '^### Profile Confirmation Gate' "$AUTOPILOT"
}

@test "AC4: gate block restricts firing to --profile path only" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/gate_scope.txt
  grep -qiE 'only when --profile|--profile.*specified|fires.*--profile|gate.*--profile path' /tmp/gate_scope.txt
}

@test "AC4: gate block does not reference --light or --heavy as trigger" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/gate_scope.txt
  ! grep -qE -e '--light' /tmp/gate_scope.txt
  ! grep -qE -e '--heavy' /tmp/gate_scope.txt
}

@test "AC4: gate uses AskUserQuestion with Apply this profile? text" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/gate_scope.txt
  grep -q 'AskUserQuestion' /tmp/gate_scope.txt
  grep -q 'Apply this profile?' /tmp/gate_scope.txt
}

@test "AC4: gate documents text fallback (Reply with 1/2)" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/gate_scope.txt
  grep -qE 'Reply with 1.*apply.*2.*cancel|1 \(apply\).*2 \(cancel\)' /tmp/gate_scope.txt
}

@test "AC4: gate halts before Team / worktree creation on Cancel" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/gate_scope.txt
  grep -qiE 'Team.*not created|worktree.*not created|halt.*before Phase 0\.9|cancel.*halt' /tmp/gate_scope.txt
}

# --- AC6: NL unknown role / unknown model halt ---

@test "AC6: autopilot.md includes Could not resolve error message" {
  grep -q 'Could not resolve:' "$AUTOPILOT"
}

@test "AC6: NL error message notes model override only scope with sonnet/opus/haiku" {
  grep -qE 'Supported: model override only.*sonnet/opus/haiku' "$AUTOPILOT"
}

@test "AC6: NL error message enumerates all 6 known roles" {
  grep -qE 'Known roles:.*developer/qa/tester/reviewer/researcher/writer' "$AUTOPILOT"
}

@test "AC6: NL parse failure halts before Team / worktree creation" {
  # Must be stated that Team / worktree is not created on parse fail.
  grep -qiE 'No Team.*worktree.*created|Team / worktree is not created' "$AUTOPILOT"
}
