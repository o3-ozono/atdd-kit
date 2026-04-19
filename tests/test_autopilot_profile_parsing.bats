#!/usr/bin/env bats

# Issue #109 — Phase 0 Argument Parsing error-path drift-detect.
#
# Scope:
#   AC4  — Unknown flag halt
#   AC5  — Conflicting preset flags (--light + --heavy) halt
#   AC10 — Utility mode (sweep/eval) rejects profile flags
#   AC11 — search mode separates keyword from --light/--heavy
#   AC16 — Preset flag + NL profile are mutually exclusive
#   AC19 — search mode disallows positional NL (requires --profile)
#   AC20 — Positional NL + --profile simultaneous use halts
#
# Strategy: drift-detect via grep on commands/autopilot.md to verify that the
# Phase 0 Argument Parsing sub-heading contains each error message literal.

AUTOPILOT="${BATS_TEST_DIRNAME}/../commands/autopilot.md"

extract_argparse_block() {
  # Print lines from "### Phase 0 Argument Parsing" (or variant) to the next
  # "## " or "### " heading (exclusive). Restricted to the first Phase 0
  # parsing block.
  awk '
    /^### Phase 0 Argument Parsing/ { in_block=1; next }
    in_block && /^## / { exit }
    in_block && /^### / { exit }
    in_block { print }
  ' "$AUTOPILOT"
}

@test "autopilot.md exists" {
  [ -f "$AUTOPILOT" ]
}

@test "Phase 0 Argument Parsing sub-heading exists" {
  grep -qE '^### Phase 0 Argument Parsing' "$AUTOPILOT"
}

# --- AC4: Unknown flag halt ---

@test "AC4: autopilot.md specifies Unknown flag error message" {
  extract_argparse_block | grep -q 'Unknown flag:'
}

@test "AC4: Unknown flag message enumerates supported flags" {
  extract_argparse_block | grep -qE 'Unknown flag.*--light.*--heavy.*--profile' \
    || extract_argparse_block | grep -qE 'supported.*--light.*--heavy.*--profile'
}

@test "AC4: Unknown flag path halts before Phase 0.9" {
  # Must reference halt semantics within the argparse block.
  extract_argparse_block | grep -qiE 'halt|stop|exit|before Phase 0\.9'
}

# --- AC5: Conflicting preset flags ---

@test "AC5: autopilot.md specifies Conflicting flags error message" {
  extract_argparse_block | grep -q 'Conflicting flags:'
}

@test "AC5: Conflicting flags message names --light and --heavy" {
  extract_argparse_block | grep -qE 'Conflicting flags.*--light.*--heavy' \
    || extract_argparse_block | grep -qE '--light.*--heavy.*choose one'
}

# --- AC10: Utility mode rejects profile flags ---

@test "AC10: autopilot.md specifies utility mode profile rejection" {
  extract_argparse_block | grep -qE 'utility mode|Profile flags are not supported'
}

@test "AC10: utility mode rejection names sweep and eval" {
  extract_argparse_block | grep -qE 'sweep|eval'
}

# --- AC11: search mode separates keyword from preset flag ---

@test "AC11: autopilot.md describes search mode flag separation" {
  extract_argparse_block | grep -qiE 'search.*keyword|separate.*keyword|keyword.*--light'
}

# --- AC16: Preset + NL mutual exclusion ---

@test "AC16: autopilot.md specifies Conflicting profile sources error" {
  extract_argparse_block | grep -q 'Conflicting profile sources'
}

@test "AC16: Conflicting profile sources message names preset and custom text" {
  extract_argparse_block | grep -qE 'Conflicting profile sources.*--light.*custom profile text' \
    || extract_argparse_block | grep -qE 'Conflicting profile sources.*--heavy.*custom'
}

# --- AC19: search mode + positional NL constraint ---

@test "AC19: autopilot.md describes search mode NL constraint" {
  extract_argparse_block | grep -qE 'In search mode.*custom profile must be specified via --profile'
}

@test "AC19: message clarifies positional NL only after issue number" {
  extract_argparse_block | grep -qE 'Positional NL is only valid after an issue number'
}

# --- AC20: Positional NL + --profile simultaneous halt ---

@test "AC20: autopilot.md specifies Multiple NL profile sources error" {
  extract_argparse_block | grep -q 'Multiple NL profile sources'
}

@test "AC20: message instructs to use either positional or --profile" {
  extract_argparse_block | grep -qE 'Use either positional text or --profile'
}

# --- Argument parsing structural requirements ---

@test "AC9 structural: argparse block documents position-independence" {
  # flags should work before or after the issue number.
  extract_argparse_block | grep -qiE 'position.*independ|order.*independ|before or after|either before'
}

@test "AC15 structural: argparse block accepts --profile= and --profile space forms" {
  extract_argparse_block | grep -qE -e '--profile=' \
    && extract_argparse_block | grep -qE -e '--profile "'
}
