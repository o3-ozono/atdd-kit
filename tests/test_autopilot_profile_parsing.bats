#!/usr/bin/env bats

# Issue #122 — Phase 0 Argument Parsing drift-detect (post-simplification).
#
# Scope:
#   AC5 — --light / --heavy are Unknown flag halts with BREAKING notice
#
# The 2-path simplification (default / --profile) removes preset flags and
# therefore removes the AC5/AC11/AC16/AC19/AC20 flag-interaction tests from
# Issue #109. Only --profile remains as a recognized flag; everything else is
# an Unknown flag halt.

AUTOPILOT="${BATS_TEST_DIRNAME}/../commands/autopilot.md"

extract_argparse_block() {
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

# --- AC5: --light / --heavy are Unknown flag halts with BREAKING notice ---

@test "AC5: argparse block specifies Unknown flag halt for --light" {
  extract_argparse_block | grep -qE 'Unknown flag: --light'
}

@test "AC5: argparse block specifies Unknown flag halt for --heavy" {
  extract_argparse_block | grep -qE 'Unknown flag: --heavy'
}

@test "AC5: Unknown flag message notes BREAKING removal and --profile replacement" {
  extract_argparse_block | grep -qE 'removed in BREAKING change.*use --profile'
}

@test "AC5: Unknown flag message enumerates supported flags (only --profile)" {
  # Since --light / --heavy are gone, only --profile is supported.
  extract_argparse_block | grep -qE 'supported: --profile'
}

@test "AC5: Unknown flag halt occurs before Phase 0.9" {
  extract_argparse_block | grep -qiE 'halt|before Phase 0\.9'
}

# --- Removal of legacy error-path tests (--light/--heavy conflict, preset vs NL mutual exclusion) ---

@test "removal: argparse block no longer documents Conflicting flags: --light, --heavy" {
  ! extract_argparse_block | grep -qE 'Conflicting flags:.*--light.*--heavy'
}

@test "removal: argparse block no longer documents Conflicting profile sources" {
  ! extract_argparse_block | grep -q 'Conflicting profile sources'
}

@test "removal: argparse block no longer documents Multiple NL profile sources" {
  ! extract_argparse_block | grep -q 'Multiple NL profile sources'
}

@test "removal: argparse block no longer documents positional NL" {
  # Positional NL after issue number is no longer a supported path — everything
  # NL must go through --profile.
  ! extract_argparse_block | grep -qiE 'positional NL|positional.*natural language'
}

# --- --profile delimiter forms still supported ---

@test "structural: argparse block accepts both --profile= and --profile space forms" {
  extract_argparse_block | grep -qE -e '--profile=' \
    && extract_argparse_block | grep -qE -e '--profile "'
}
