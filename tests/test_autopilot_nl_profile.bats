#!/usr/bin/env bats

# Issue #109 — NL (natural language) profile drift-detect.
#
# Scope:
#   AC14 — Positional NL after issue number resolves to per-role matrix
#   AC15 — --profile flag accepts both = and space delimiters
#   AC17 — Resolved matrix confirmation gate (AskUserQuestion + fallback)
#   AC18 — NL parse failure halts with explanatory message

AUTOPILOT="${BATS_TEST_DIRNAME}/../commands/autopilot.md"

# --- AC14: Positional NL ---

@test "AC14: autopilot.md documents positional NL after issue number" {
  grep -qiE 'positional NL|positional.*natural language|trailing NL|trailing natural' "$AUTOPILOT"
}

@test "AC14: NL Resolution Examples block exists with nl-example markers" {
  grep -q '<!-- nl-example start -->' "$AUTOPILOT" \
    && grep -q '<!-- nl-example end -->' "$AUTOPILOT"
}

@test "AC14: NL Resolution Examples show per-role resolution" {
  awk '/<!-- nl-example start -->/,/<!-- nl-example end -->/' "$AUTOPILOT" > /tmp/nl_examples.txt
  # The example must show a resolved matrix with at least 2 distinct roles
  # receiving different models.
  grep -qE 'reviewer.*sonnet|reviewer.*opus' /tmp/nl_examples.txt \
    && grep -qE 'developer.*sonnet|developer.*opus' /tmp/nl_examples.txt
}

# --- AC15: --profile delimiter forms ---

@test "AC15: autopilot.md shows --profile= delimiter form" {
  grep -qE -e '--profile=' "$AUTOPILOT"
}

@test "AC15: autopilot.md shows --profile (space delimiter) form" {
  grep -qE -e '--profile "' "$AUTOPILOT"
}

@test "AC15: argparse block notes both forms are accepted" {
  awk '/^### Phase 0 Argument Parsing/{in_block=1; next} in_block && /^## /{exit} in_block && /^### /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/argparse.txt
  grep -qiE 'both.*form|either.*form|= (or|and) space|space.*or.*=' /tmp/argparse.txt
}

# --- AC17: Confirmation gate with AskUserQuestion + fallback ---

@test "AC17: confirmation gate references AskUserQuestion" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/gate.txt
  grep -q 'AskUserQuestion' /tmp/gate.txt
}

@test "AC17: confirmation gate asks 'Apply this profile?'" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/gate.txt
  grep -q 'Apply this profile?' /tmp/gate.txt
}

@test "AC17: confirmation gate defines text fallback (Reply with 1 or 2)" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/gate.txt
  grep -qE 'Reply with 1.*apply.*2.*cancel|1 \(apply\).*2 \(cancel\)' /tmp/gate.txt
}

@test "AC17: gate halts until approval (no Team/worktree creation)" {
  awk '/^### Profile Confirmation Gate/{in_block=1; next} in_block && /^### /{exit} in_block && /^## /{exit} in_block{print}' \
    "$AUTOPILOT" > /tmp/gate.txt
  grep -qiE 'Team.*not created|worktree.*not created|until.*approv|do not.*create.*Team' /tmp/gate.txt
}

# --- AC18: NL parse failure ---

@test "AC18: autopilot.md specifies Could not resolve error message" {
  grep -q 'Could not resolve:' "$AUTOPILOT"
}

@test "AC18: NL parse error message notes model override only scope" {
  grep -qE 'Supported: model override only.*sonnet/opus/haiku' "$AUTOPILOT"
}

@test "AC18: NL parse error message notes effort control unsupported" {
  grep -qE 'Effort control is not supported in this release' "$AUTOPILOT"
}

@test "AC18: NL parse error message lists known roles" {
  grep -qE 'Known roles:.*developer/qa/tester/reviewer/researcher/writer' "$AUTOPILOT"
}
