#!/usr/bin/env bats

# =============================================================================
# circuit_breaker.sh -- Unit tests
# Issue #56: autopilot にサーキットブレーカーを導入し無限ループを防止する
#
# AC1: Initialization & resilience
# AC2: Progress signal behavior
# AC3: No-progress threshold — CLOSED → HALF_OPEN → OPEN
# AC4: Same-error threshold — 5 consecutive identical fingerprints → OPEN
# AC5: check gate — halt only in OPEN
# AC6: Manual reset
# AC7: Unknown subcommand
# AC8: State file is worktree-scoped
# =============================================================================

CB_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/lib/circuit_breaker.sh"

setup() {
  WORK="${BATS_TMPDIR}/cb-work-$$"
  mkdir -p "${WORK}/.claude"
  STATE_FILE="${WORK}/.claude/cb-state.json"
}

teardown() {
  rm -rf "${WORK}"
}

# Helper: write a state JSON
write_state() {
  local state="$1" np="$2" ec="$3" fp="$4"
  local path="${5:-${WORK}}"
  printf '{"state":"%s","no_progress":%s,"error_count":%s,"last_error_fingerprint":"%s"}\n' \
    "$state" "$np" "$ec" "$fp" > "${path}/.claude/cb-state.json"
}

# Helper: run cb script with cwd set to WORK
run_cb() {
  cd "$WORK"
  run bash "$CB_SCRIPT" "$@"
}

# Helper: get a field from the state file
get_state_field() {
  jq -r ".$1" "${WORK}/.claude/cb-state.json"
}

# =============================================================================
# AC7: Unknown subcommand
# =============================================================================

@test "AC7: unknown subcommand exits non-zero" {
  run_cb unknown_command
  [ "$status" -ne 0 ]
}

@test "AC7: unknown subcommand writes usage to stderr" {
  run --separate-stderr bash "$CB_SCRIPT" unknown_command
  [[ "$stderr" =~ [Uu]sage ]] || [[ "$stderr" =~ [Vv]alid ]]
}

@test "AC7: no argument exits non-zero with usage in stderr" {
  run --separate-stderr bash "$CB_SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$stderr" =~ [Uu]sage ]] || [[ "$stderr" =~ [Vv]alid ]]
}

# =============================================================================
# AC1: Initialization & resilience
# =============================================================================

@test "AC1: missing state file — auto-creates with CLOSED defaults" {
  # No state file exists
  [ ! -f "${WORK}/.claude/cb-state.json" ]
  run_cb check
  [ "$status" -eq 0 ]
  [ -f "${WORK}/.claude/cb-state.json" ]
}

@test "AC1: auto-created state has correct defaults" {
  run_cb check
  [ "$(get_state_field state)" = "CLOSED" ]
  [ "$(get_state_field no_progress)" = "0" ]
  [ "$(get_state_field error_count)" = "0" ]
  [ "$(get_state_field last_error_fingerprint)" = "" ]
}

@test "AC1: malformed JSON exits non-zero" {
  echo "not_json" > "${WORK}/.claude/cb-state.json"
  run_cb check
  [ "$status" -ne 0 ]
}

@test "AC1: malformed JSON stderr contains file path and reset hint" {
  echo "not_json" > "${WORK}/.claude/cb-state.json"
  cd "$WORK"
  run --separate-stderr bash "$CB_SCRIPT" check
  [[ "$stderr" =~ cb-state.json ]]
  [[ "$stderr" =~ reset ]]
}

# =============================================================================
# AC2: Progress signal behavior
# =============================================================================

@test "AC2: record_progress from CLOSED — stays CLOSED, clears counters" {
  write_state "CLOSED" 1 2 "some_fp"
  run_cb record_progress
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "CLOSED" ]
  [ "$(get_state_field no_progress)" = "0" ]
  [ "$(get_state_field error_count)" = "0" ]
  [ "$(get_state_field last_error_fingerprint)" = "" ]
}

@test "AC2: record_progress from HALF_OPEN — resets to CLOSED, clears counters" {
  write_state "HALF_OPEN" 2 0 ""
  run_cb record_progress
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "CLOSED" ]
  [ "$(get_state_field no_progress)" = "0" ]
}

@test "AC2: record_progress from OPEN — state unchanged (sticky)" {
  write_state "OPEN" 3 0 ""
  run_cb record_progress
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "OPEN" ]
}

@test "AC2: record_progress from OPEN — counters unchanged" {
  write_state "OPEN" 3 2 "some_fp"
  run_cb record_progress
  [ "$(get_state_field no_progress)" = "3" ]
  [ "$(get_state_field error_count)" = "2" ]
}

# =============================================================================
# AC3: No-progress threshold — CLOSED → HALF_OPEN → OPEN
# =============================================================================

@test "AC3: 1st record_no_progress — CLOSED, no_progress=1" {
  write_state "CLOSED" 0 0 ""
  run_cb record_no_progress
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "CLOSED" ]
  [ "$(get_state_field no_progress)" = "1" ]
}

@test "AC3: 2nd record_no_progress — HALF_OPEN, no_progress=2" {
  write_state "CLOSED" 1 0 ""
  run_cb record_no_progress
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "HALF_OPEN" ]
  [ "$(get_state_field no_progress)" = "2" ]
}

@test "AC3: 3rd record_no_progress — OPEN, no_progress=3" {
  write_state "HALF_OPEN" 2 0 ""
  run_cb record_no_progress
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "OPEN" ]
  [ "$(get_state_field no_progress)" = "3" ]
}

@test "AC3: OPEN record_no_progress — idempotent, no_progress stays at 3" {
  write_state "OPEN" 3 0 ""
  run_cb record_no_progress
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "OPEN" ]
  [ "$(get_state_field no_progress)" = "3" ]
}

@test "AC3: record_progress between no_progress resets to CLOSED/no_progress=0" {
  write_state "HALF_OPEN" 2 0 ""
  run_cb record_progress
  [ "$(get_state_field state)" = "CLOSED" ]
  [ "$(get_state_field no_progress)" = "0" ]
}

@test "AC3: each transition persisted to cb-state.json" {
  write_state "CLOSED" 0 0 ""
  run_cb record_no_progress
  [ -f "${WORK}/.claude/cb-state.json" ]
  [ "$(get_state_field state)" = "CLOSED" ]
  run_cb record_no_progress
  [ "$(get_state_field state)" = "HALF_OPEN" ]
  run_cb record_no_progress
  [ "$(get_state_field state)" = "OPEN" ]
}

# =============================================================================
# AC4: Same-error threshold — 5 consecutive identical fingerprints → OPEN
# =============================================================================

@test "AC4: 5th same fingerprint → OPEN" {
  write_state "CLOSED" 0 4 "fp_test"
  run_cb record_error fp_test
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "OPEN" ]
  [ "$(get_state_field error_count)" = "5" ]
}

@test "AC4: different fingerprint resets error_count to 1" {
  write_state "CLOSED" 0 3 "old_fp"
  run_cb record_error new_fp
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "CLOSED" ]
  [ "$(get_state_field error_count)" = "1" ]
  [ "$(get_state_field last_error_fingerprint)" = "new_fp" ]
}

@test "AC4: record_error in OPEN state — no-op, exit 0" {
  write_state "OPEN" 3 5 "fp_test"
  run_cb record_error fp_test
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "OPEN" ]
  [ "$(get_state_field error_count)" = "5" ]
}

@test "AC4: invalid fingerprint chars — stderr + exit non-zero" {
  write_state "CLOSED" 0 0 ""
  run --separate-stderr bash "$CB_SCRIPT" record_error "invalid/fingerprint"
  [ "$status" -ne 0 ]
  [[ "$stderr" =~ [Ff]ingerprint ]] || [[ "$stderr" =~ [Ii]nvalid ]]
}

@test "AC4: valid fingerprint chars accepted — [a-zA-Z0-9_-]" {
  write_state "CLOSED" 0 0 ""
  run_cb record_error "Valid-FP_123"
  [ "$status" -eq 0 ]
}

# =============================================================================
# AC5: check gate — halt only in OPEN
# =============================================================================

@test "AC5: check from CLOSED — exit 0" {
  write_state "CLOSED" 0 0 ""
  run_cb check
  [ "$status" -eq 0 ]
}

@test "AC5: check from HALF_OPEN — exit 0" {
  write_state "HALF_OPEN" 2 0 ""
  run_cb check
  [ "$status" -eq 0 ]
}

@test "AC5: check from OPEN — exit non-zero" {
  write_state "OPEN" 3 0 ""
  run_cb check
  [ "$status" -ne 0 ]
}

@test "AC5: check from OPEN — stdout contains OPEN" {
  write_state "OPEN" 3 0 ""
  run_cb check
  [[ "$output" =~ OPEN ]]
}

@test "AC5: check from OPEN via no_progress — stdout contains no_progress trip reason" {
  write_state "OPEN" 3 0 ""
  run_cb check
  [[ "$output" =~ no_progress ]] || [[ "$output" =~ "no progress" ]] || [[ "$output" =~ "progress" ]]
}

@test "AC5: check from OPEN via error — stdout contains fingerprint" {
  write_state "OPEN" 0 5 "some_error_fp"
  run_cb check
  [[ "$output" =~ some_error_fp ]]
}

@test "AC5: check from OPEN — stdout contains reset command" {
  write_state "OPEN" 3 0 ""
  run_cb check
  [[ "$output" =~ "circuit_breaker.sh reset" ]] || [[ "$output" =~ "lib/circuit_breaker.sh reset" ]]
}

# =============================================================================
# AC6: Manual reset
# =============================================================================

@test "AC6: reset from OPEN — state becomes CLOSED" {
  write_state "OPEN" 3 5 "some_fp"
  run_cb reset
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "CLOSED" ]
}

@test "AC6: reset clears no_progress to 0" {
  write_state "OPEN" 3 0 ""
  run_cb reset
  [ "$(get_state_field no_progress)" = "0" ]
}

@test "AC6: reset clears error_count to 0" {
  write_state "OPEN" 0 5 "fp"
  run_cb reset
  [ "$(get_state_field error_count)" = "0" ]
}

@test "AC6: reset clears last_error_fingerprint" {
  write_state "OPEN" 0 5 "fp"
  run_cb reset
  [ "$(get_state_field last_error_fingerprint)" = "" ]
}

@test "AC6: reset from HALF_OPEN — also works" {
  write_state "HALF_OPEN" 2 0 ""
  run_cb reset
  [ "$status" -eq 0 ]
  [ "$(get_state_field state)" = "CLOSED" ]
}

@test "AC6: reset creates valid JSON state file" {
  write_state "OPEN" 3 5 "fp"
  run_cb reset
  jq -e '.state == "CLOSED"' "${WORK}/.claude/cb-state.json" > /dev/null
}

# =============================================================================
# AC8: State file is worktree-scoped
# =============================================================================

@test "AC8: state file created at cwd/.claude/cb-state.json" {
  run_cb check
  [ -f "${WORK}/.claude/cb-state.json" ]
}

@test "AC8: separate cwd yields separate state files" {
  # Set up two separate worktrees
  WORK2="${BATS_TMPDIR}/cb-work2-$$"
  mkdir -p "${WORK2}/.claude"

  # Write different states to each worktree
  write_state "CLOSED" 0 0 "" "${WORK}"
  write_state "OPEN" 3 0 "" "${WORK2}"

  # check in WORK should succeed (CLOSED)
  cd "$WORK"
  run bash "$CB_SCRIPT" check
  [ "$status" -eq 0 ]

  # check in WORK2 should fail (OPEN)
  cd "$WORK2"
  run bash "$CB_SCRIPT" check
  [ "$status" -ne 0 ]

  rm -rf "${WORK2}"
}
