#!/usr/bin/env bats
# @covers: scripts/test-skills-headless.sh
bats_require_minimum_version 1.5.0

# =============================================================================
# test_headless_exit_codes.bats -- 12-case exit-code matrix
# Issue #72 / AC5
#
#  # | exit | category    | trigger
#  1 |  0   | success     | happy fixture + subsequence
#  2 |  1   | assertion   | out-of-order.jsonl replay
#  3 |  1   | assertion   | missing-skill.jsonl replay
#  4 |  1   | assertion   | forbidden-present.jsonl replay
#  5 |  1   | assertion   | strict-extra.jsonl + match_mode=strict
#  6 |  2   | parse_error | malformed.truncated.jsonl
#  7 |  2   | parse_error | malformed.invalid-json.jsonl
#  8 |  2   | parse_error | malformed.missing-field.jsonl
#  9 |  2   | parse_error | malformed.non-utf8.bin
# 10 |  3   | infra       | HEADLESS_CLAUDE_BIN=/nonexistent (live mode)
# 11 |  3   | infra       | scenario schema violation (invalid match_mode)
# 12 |  4   | timeout     | HEADLESS_CLAUDE_BIN=sleep-stub + timeout=1
# =============================================================================

RUNNER="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts/test-skills-headless.sh"
FIXTURES="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/tests/fixtures/headless"

setup() {
  WORK="${BATS_TMPDIR}/exit-codes-$$"
  mkdir -p "$WORK"
}

teardown() {
  rm -rf "$WORK"
}

# Helper: make a scenario JSON pointing at a given fixture + mode
make_scenario() {
  local path="$1" expected="$2" forbidden="$3" mode="$4" fixture="$5" timeout="${6:-1800}"
  local model_field="${7:-}"
  jq -n --argjson expected "$expected" --argjson forbidden "$forbidden" \
    --arg mode "$mode" --arg fixture "$fixture" --arg model "$model_field" \
    --argjson timeout "$timeout" '{
      version: 1,
      name: "test-case",
      prompt: "(n/a)",
      expected_skills: $expected,
      forbidden_skills: $forbidden,
      match_mode: $mode,
      timeout: $timeout,
      fixture: $fixture
    } + (if $model == "" then {} else {model: $model} end)' > "$path"
}

# -----------------------------------------------------------------------------
# Case 1 — PASS
# -----------------------------------------------------------------------------
@test "case 1 (exit 0): happy fixture + subsequence" {
  local sc="$WORK/c1.json"
  make_scenario "$sc" '["atdd-kit:discover","atdd-kit:plan"]' '[]' "subsequence" "$FIXTURES/discover-plan.happy.jsonl"
  run bash "$RUNNER" --replay "$FIXTURES/discover-plan.happy.jsonl" "$sc"
  [ "$status" -eq 0 ]
}

# -----------------------------------------------------------------------------
# Cases 2-5 — assertion FAIL (exit 1)
# -----------------------------------------------------------------------------
@test "case 2 (exit 1): out-of-order.jsonl replay" {
  local sc="$WORK/c2.json"
  make_scenario "$sc" '["atdd-kit:discover","atdd-kit:plan"]' '[]' "subsequence" "$FIXTURES/out-of-order.jsonl"
  run bash "$RUNNER" --replay "$FIXTURES/out-of-order.jsonl" "$sc"
  [ "$status" -eq 1 ]
}

@test "case 3 (exit 1): missing-skill.jsonl replay" {
  local sc="$WORK/c3.json"
  make_scenario "$sc" '["atdd-kit:discover","atdd-kit:plan"]' '[]' "subsequence" "$FIXTURES/missing-skill.jsonl"
  run bash "$RUNNER" --replay "$FIXTURES/missing-skill.jsonl" "$sc"
  [ "$status" -eq 1 ]
}

@test "case 4 (exit 1): forbidden-present.jsonl replay" {
  local sc="$WORK/c4.json"
  make_scenario "$sc" '["atdd-kit:discover","atdd-kit:plan"]' '["atdd-kit:atdd"]' "subsequence" "$FIXTURES/forbidden-present.jsonl"
  run bash "$RUNNER" --replay "$FIXTURES/forbidden-present.jsonl" "$sc"
  [ "$status" -eq 1 ]
}

@test "case 5 (exit 1): strict-extra.jsonl + match_mode=strict" {
  local sc="$WORK/c5.json"
  make_scenario "$sc" '["atdd-kit:discover","atdd-kit:plan"]' '[]' "strict" "$FIXTURES/strict-extra.jsonl"
  run bash "$RUNNER" --replay "$FIXTURES/strict-extra.jsonl" "$sc"
  [ "$status" -eq 1 ]
}

# -----------------------------------------------------------------------------
# Cases 6-9 — parse_error (exit 2)
# -----------------------------------------------------------------------------
@test "case 6 (exit 2): malformed.truncated.jsonl" {
  local sc="$WORK/c6.json"
  make_scenario "$sc" '["x"]' '[]' "subsequence" "$FIXTURES/malformed.truncated.jsonl"
  run bash "$RUNNER" --replay "$FIXTURES/malformed.truncated.jsonl" "$sc"
  [ "$status" -eq 2 ]
}

@test "case 7 (exit 2): malformed.invalid-json.jsonl" {
  local sc="$WORK/c7.json"
  make_scenario "$sc" '["x"]' '[]' "subsequence" "$FIXTURES/malformed.invalid-json.jsonl"
  run bash "$RUNNER" --replay "$FIXTURES/malformed.invalid-json.jsonl" "$sc"
  [ "$status" -eq 2 ]
}

@test "case 8 (exit 2): malformed.missing-field.jsonl" {
  local sc="$WORK/c8.json"
  make_scenario "$sc" '["x"]' '[]' "subsequence" "$FIXTURES/malformed.missing-field.jsonl"
  run bash "$RUNNER" --replay "$FIXTURES/malformed.missing-field.jsonl" "$sc"
  [ "$status" -eq 2 ]
}

@test "case 9 (exit 2): malformed.non-utf8.bin" {
  local sc="$WORK/c9.json"
  make_scenario "$sc" '["x"]' '[]' "subsequence" "$FIXTURES/malformed.non-utf8.bin"
  run bash "$RUNNER" --replay "$FIXTURES/malformed.non-utf8.bin" "$sc"
  [ "$status" -eq 2 ]
}

# -----------------------------------------------------------------------------
# Case 10 — infra: missing claude binary (live mode)
# -----------------------------------------------------------------------------
@test "case 10 (exit 3): HEADLESS_CLAUDE_BIN=/nonexistent" {
  local sc="$WORK/c10.json"
  make_scenario "$sc" '["atdd-kit:discover"]' '[]' "subsequence" "$FIXTURES/discover-plan.happy.jsonl"
  HEADLESS_CLAUDE_BIN=/nonexistent run bash "$RUNNER" "$sc"
  [ "$status" -eq 3 ]
}

# -----------------------------------------------------------------------------
# Case 11 — infra: scenario schema violation
# -----------------------------------------------------------------------------
@test "case 11 (exit 3): scenario schema violation (invalid match_mode)" {
  run bash "$RUNNER" --replay "$FIXTURES/discover-plan.happy.jsonl" \
    "$FIXTURES/schema-invalid-mode.scenario.json"
  [ "$status" -eq 3 ]
}

# -----------------------------------------------------------------------------
# Case 12 — timeout (live mode with sleep stub)
# -----------------------------------------------------------------------------
@test "case 12 (exit 4): HEADLESS_CLAUDE_BIN=sleep-stub + timeout=1" {
  local sc="$WORK/c12.json"
  local stub="$WORK/sleep-stub.sh"
  cat > "$stub" <<'EOF'
#!/usr/bin/env bash
sleep 30
EOF
  chmod +x "$stub"
  make_scenario "$sc" '["atdd-kit:discover"]' '[]' "subsequence" "$FIXTURES/discover-plan.happy.jsonl" 1

  HEADLESS_CLAUDE_BIN="$stub" HEADLESS_TEMP_DIR="$WORK/tmp" run bash "$RUNNER" "$sc"
  [ "$status" -eq 4 ]
}

# -----------------------------------------------------------------------------
# Case 13 — empty transcript → exit 1 (AC2 / Issue #125)
# -----------------------------------------------------------------------------
@test "case 13 (exit 1): empty transcript file" {
  local sc="$WORK/c13.json"
  local empty_transcript="$WORK/empty.jsonl"
  touch "$empty_transcript"
  make_scenario "$sc" '["atdd-kit:discover"]' '[]' "subsequence" "$empty_transcript"
  run bash "$RUNNER" --replay "$empty_transcript" "$sc"
  [ "$status" -eq 1 ]
}
