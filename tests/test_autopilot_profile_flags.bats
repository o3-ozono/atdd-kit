#!/usr/bin/env bats

# Issue #109 — Preset profile flag drift-detect.
#
# Scope:
#   AC1  — --light applies sonnet to all sub-agents
#   AC2  — No flag inherits session default (model param omitted)
#   AC6  — Resolved matrix echo visible to user before Phase 0.9
#   AC7  — --heavy applies opus to all sub-agents
#   AC9  — Flag position independence (before or after issue number)
#   AC12 — Mid-phase resume: flag still applies to fresh spawns
#
# Strategy: drift-detect on commands/autopilot.md — spawn specs must reference
# config/spawn-profiles.yml for model resolution, and the Usage / argparse
# sections must document the contract.

AUTOPILOT="${BATS_TEST_DIRNAME}/../commands/autopilot.md"

# --- AC1 / AC7: preset flags map to config/spawn-profiles.yml ---

@test "AC1: autopilot.md references --light flag" {
  grep -qE -e '--light' "$AUTOPILOT"
}

@test "AC7: autopilot.md references --heavy flag" {
  grep -qE -e '--heavy' "$AUTOPILOT"
}

@test "AC1/AC7: spawn specs reference config/spawn-profiles.yml" {
  grep -q 'config/spawn-profiles.yml' "$AUTOPILOT"
}

@test "AC1/AC7: Usage section shows --light and --heavy examples" {
  awk '/^## Usage/{in_block=1; next} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" | grep -qE -e '--light' \
    && awk '/^## Usage/{in_block=1; next} in_block && /^## /{exit} in_block{print}' \
         "$AUTOPILOT" | grep -qE -e '--heavy'
}

# --- AC2: no-flag path omits model ---

@test "AC2: autopilot.md documents session default (no model param) path" {
  grep -qE 'session default|omit.*model|no.*flag.*inherit' "$AUTOPILOT"
}

@test "AC2: spawn specs note model parameter is omitted when no profile is set" {
  # Must mention that `model` is omitted from Agent tool calls under no-flag.
  grep -qE 'model.*omit|omit.*model|no model|without.*model' "$AUTOPILOT"
}

# --- AC6: Resolved matrix echo ---

@test "AC6: autopilot.md contains Profile Confirmation Gate sub-heading" {
  grep -qE '^### Profile Confirmation Gate' "$AUTOPILOT"
}

@test "AC6: confirmation gate references 6 agent roles" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/profile_gate_block.txt
  for role in developer qa tester reviewer researcher writer; do
    grep -q "$role" /tmp/profile_gate_block.txt \
      || { echo "gate missing role: $role"; return 1; }
  done
}

@test "AC6: confirmation gate fires before Phase 0.9" {
  # The gate heading must appear in the file before the Phase 0.9 heading.
  gate_line=$(grep -n '^### Profile Confirmation Gate' "$AUTOPILOT" | head -1 | cut -d: -f1)
  phase09_line=$(grep -n '^## Phase 0.9' "$AUTOPILOT" | head -1 | cut -d: -f1)
  [ -n "$gate_line" ] && [ -n "$phase09_line" ] && [ "$gate_line" -lt "$phase09_line" ]
}

# --- AC9: Flag position independence ---

@test "AC9: autopilot.md documents flag position independence" {
  grep -qiE 'position.*independ|order.*independ|before or after|either before|either position' "$AUTOPILOT"
}

# --- AC12: Mid-phase resume applies flag ---

@test "AC12: autopilot.md notes profile flag applies to fresh spawns on resume" {
  # Phase 0.5 / mid-phase resume must mention that profile still applies.
  grep -qE 'mid-phase resume.*profile|profile.*applies.*(resume|Phase 3|fresh spawn)|resume.*profile flag' "$AUTOPILOT"
}

# --- Spawn spec references: all 5 spawn sites explicitly pass model ---

@test "AC1/AC7: spawn specs describe passing model parameter per profile" {
  # References to Agent tool model passing must appear near each spawn site
  # (AC Review Round, Phase 3 Developer/Researcher/Writer, Phase 4 Reviewer).
  # We assert that the file contains at least one spawn spec that explicitly
  # mentions `model` parameter in an Agent tool context.
  grep -qE 'Agent tool.*model|model:.*(resolved|profile)|pass.*model.*Agent' "$AUTOPILOT"
}
