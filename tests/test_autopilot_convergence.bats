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

@test "check_stuck: progress (a differing fingerprint) within the window continues" {
  record_iteration "$JSONL" 1 "US" "FAIL" "x"
  record_iteration "$JSONL" 2 "US" "FAIL" "y"
  record_iteration "$JSONL" 3 "US" "FAIL" "x"
  run check_stuck "$JSONL" 3
  [ "$status" -eq 0 ]
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
