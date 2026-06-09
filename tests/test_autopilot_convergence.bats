#!/usr/bin/env bats
# @covers: lib/autopilot_convergence.sh
# Unit Test (behavior) for the autopilot convergence safety rails (#246).
# claude is NOT invoked; the bash functions are exercised directly so the
# safety rails (sameness-detector / stuck detection / max-iterations /
# JSONL audit log) are verified by execution, not by grep.

setup() {
  LIB="lib/autopilot_convergence.sh"
  source "$LIB"
  TMP="$(mktemp -d)"
  JSONL="$TMP/autopilot-log.jsonl"
}

teardown() {
  rm -rf "$TMP"
}

# --- fingerprint (normalized sha256) --------------------------------------

@test "fingerprint: identical content yields identical hash, different content differs" {
  a=$(echo "error X failed" | fingerprint)
  b=$(echo "error X failed" | fingerprint)
  c=$(echo "error Y failed" | fingerprint)
  [ -n "$a" ]
  [ "$a" = "$b" ]
  [ "$a" != "$c" ]
}

@test "fingerprint: whitespace jitter is normalized to the same hash" {
  a=$(printf 'error   X\n failed' | fingerprint)
  b=$(printf 'error X failed' | fingerprint)
  [ "$a" = "$b" ]
}

# --- JSONL audit log ------------------------------------------------------

@test "record_iteration: appends one JSONL line with the expected fields" {
  record_iteration "$JSONL" 1 "US" "FAIL" "abc123"
  [ -f "$JSONL" ]
  run cat "$JSONL"
  [[ "$output" == *'"iteration":1'* ]]
  [[ "$output" == *'"step":"US"'* ]]
  [[ "$output" == *'"verdict":"FAIL"'* ]]
  [[ "$output" == *'"fingerprint":"abc123"'* ]]
}

@test "record_iteration: a second call appends (does not overwrite)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  record_iteration "$JSONL" 2 "US" "FAIL" "fp2"
  run wc -l < "$JSONL"
  [ "$(echo "$output" | tr -d ' ')" -eq 2 ]
}

# --- sameness-detector (2 consecutive identical fingerprints halt) --------

@test "check_sameness: two consecutive identical fingerprints halt (non-zero)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "samefp"
  record_iteration "$JSONL" 2 "US" "FAIL" "samefp"
  run check_sameness "$JSONL"
  [ "$status" -ne 0 ]
}

@test "check_sameness: two consecutive different fingerprints continue (zero)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  record_iteration "$JSONL" 2 "US" "FAIL" "fp2"
  run check_sameness "$JSONL"
  [ "$status" -eq 0 ]
}

@test "check_sameness: a single iteration cannot be 'same' (zero)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  run check_sameness "$JSONL"
  [ "$status" -eq 0 ]
}

# --- stuck detection (no progress across a window) ------------------------

@test "check_stuck: window=3 all-identical fingerprints halt (non-zero)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "x"
  record_iteration "$JSONL" 2 "US" "FAIL" "x"
  record_iteration "$JSONL" 3 "US" "FAIL" "x"
  run check_stuck "$JSONL" 3
  [ "$status" -ne 0 ]
}

@test "check_stuck: genuine progress (all-distinct fingerprints) within the window continues" {
  record_iteration "$JSONL" 1 "US" "FAIL" "x"
  record_iteration "$JSONL" 2 "US" "FAIL" "y"
  record_iteration "$JSONL" 3 "US" "FAIL" "z"
  run check_stuck "$JSONL" 3
  [ "$status" -eq 0 ]
}

# A repeat ANYWHERE in the window = revisiting a prior state = no progress.
# This is the non-adjacent duplicate that check_sameness (last-two) misses.
@test "check_stuck: a non-adjacent repeat within the window halts (x,y,x)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "x"
  record_iteration "$JSONL" 2 "US" "FAIL" "y"
  record_iteration "$JSONL" 3 "US" "FAIL" "x"
  run check_stuck "$JSONL" 3
  [ "$status" -ne 0 ]
}

# A,B,A,B oscillation (fix-one / break-another) evades check_sameness because
# the last two are always different; check_stuck must still catch it.
@test "check_stuck: A,B,A,B oscillation halts (regression guard, #246 review)" {
  record_iteration "$JSONL" 1 "plan" "FAIL" "A"
  record_iteration "$JSONL" 2 "plan" "FAIL" "B"
  record_iteration "$JSONL" 3 "plan" "FAIL" "A"
  record_iteration "$JSONL" 4 "plan" "FAIL" "B"
  run check_sameness "$JSONL"
  [ "$status" -eq 0 ]   # sameness (last two A,B differ) does NOT catch it
  run check_stuck "$JSONL" 3
  [ "$status" -ne 0 ]   # stuck DOES catch it (window B,A,B has a repeat)
}

# --- max-iterations -------------------------------------------------------

@test "check_max_iterations: current >= max halts (non-zero)" {
  run check_max_iterations 8 8
  [ "$status" -ne 0 ]
}

@test "check_max_iterations: current < max continues (zero)" {
  run check_max_iterations 3 8
  [ "$status" -eq 0 ]
}

# --- input hardening: the audit log must stay valid + the rails must not go dark

# Round-trip every recorded line through a real JSON parser, not a substring
# match — a substring assertion passes on malformed JSON, hiding injection.
_assert_valid_jsonl() {
  run python3 -c 'import json,sys
[json.loads(l) for l in open(sys.argv[1]) if l.strip()]' "$1"
  [ "$status" -eq 0 ]
}

@test "record_iteration: a double-quote in step/verdict is escaped, log stays valid JSON" {
  record_iteration "$JSONL" 1 'US"evil' 'FAIL"injected' "abc123"
  _assert_valid_jsonl "$JSONL"
  # the quote round-trips as data inside the field, it does not break the JSON
  run python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["verdict"])' "$JSONL"
  [ "$output" = 'FAIL"injected' ]
}

@test "record_iteration: a forged-key injection via step cannot create extra JSON keys" {
  record_iteration "$JSONL" 1 'US","verdict":"PASS","fingerprint":"FORGED' "FAIL" "realfp"
  _assert_valid_jsonl "$JSONL"
  # the real fingerprint is the only one extracted — no FORGED key leaks in
  run _fingerprints "$JSONL"
  [ "$output" = "realfp" ]
}

@test "record_iteration: an empty fingerprint (missing hash tool) is refused, not written dark" {
  run record_iteration "$JSONL" 1 "US" "FAIL" ""
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "record_iteration: a newline-bearing fingerprint is refused (would split the JSONL line)" {
  run record_iteration "$JSONL" 1 "US" "FAIL" "$(printf 'a\nb')"
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "record_iteration: a quote-bearing fingerprint is refused (would break parse/forge)" {
  run record_iteration "$JSONL" 1 "US" "FAIL" 'abc"def'
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "record_iteration: a non-numeric iteration is refused (invalid JSON number)" {
  run record_iteration "$JSONL" "1; rm" "US" "FAIL" "abc123"
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "rails do not go dark: refused records leave no empty-fingerprint line behind" {
  record_iteration "$JSONL" 1 "US" "FAIL" "samefp" || true
  record_iteration "$JSONL" 2 "US" "FAIL" "" || true   # refused — not written
  record_iteration "$JSONL" 3 "US" "FAIL" "samefp" || true
  # only the two valid samefp lines exist, so sameness still fires
  run check_sameness "$JSONL"
  [ "$status" -ne 0 ]
}

# --- round-2 hardening (#246 second review) -------------------------------

@test "record_iteration: a C0 control char (form-feed) in step is collapsed, log stays valid JSON" {
  record_iteration "$JSONL" 1 "$(printf 'US\fevil')" "FAIL" "abc123"
  _assert_valid_jsonl "$JSONL"
}

@test "record_iteration: a backslash-bearing fingerprint is refused" {
  run record_iteration "$JSONL" 1 "US" "FAIL" 'abc\def'
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "record_iteration: a leading-zero iteration is normalized to a valid JSON number" {
  record_iteration "$JSONL" 007 "US" "FAIL" "abc123"
  _assert_valid_jsonl "$JSONL"
  run python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["iteration"])' "$JSONL"
  [ "$output" = "7" ]
}

@test "check_max_iterations: an empty current halts instead of fail-open continue" {
  run check_max_iterations "" 8
  [ "$status" -ne 0 ]
}

@test "check_max_iterations: a non-numeric arg halts" {
  run check_max_iterations "abc" 8
  [ "$status" -ne 0 ]
}

@test "check_stuck: a non-numeric window halts instead of silently disabling the rail" {
  record_iteration "$JSONL" 1 "US" "FAIL" "x"
  record_iteration "$JSONL" 2 "US" "FAIL" "x"
  record_iteration "$JSONL" 3 "US" "FAIL" "x"
  run check_stuck "$JSONL" "3; echo PWNED"
  [ "$status" -ne 0 ]
}
