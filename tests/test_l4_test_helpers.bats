#!/usr/bin/env bats
# test_l4_test_helpers.bats -- AC1: fast-test harness

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
TEST_HELPERS="${REPO_ROOT}/tests/claude-code/test-helpers.sh"

setup() {
  # Override claude binary with a stub that echoes a known response
  export SKILL_TEST_CLAUDE_BIN="${BATS_TEST_TMPDIR}/stub-claude.sh"
  cat > "$SKILL_TEST_CLAUDE_BIN" <<'EOF'
#!/usr/bin/env bash
# stub claude: echo fixed output for testing
echo "Yes, the skill triggers on that phrase."
EOF
  chmod +x "$SKILL_TEST_CLAUDE_BIN"
}

teardown() {
  unset SKILL_TEST_CLAUDE_BIN
}

@test "test-helpers.sh exists and is sourceable" {
  [ -f "$TEST_HELPERS" ]
  source "$TEST_HELPERS"
}

@test "run_claude is defined after sourcing test-helpers" {
  source "$TEST_HELPERS"
  declare -f run_claude > /dev/null
}

@test "assert_contains is defined after sourcing test-helpers" {
  source "$TEST_HELPERS"
  declare -f assert_contains > /dev/null
}

@test "assert_order is defined after sourcing test-helpers" {
  source "$TEST_HELPERS"
  declare -f assert_order > /dev/null
}

@test "assert_count is defined after sourcing test-helpers" {
  source "$TEST_HELPERS"
  declare -f assert_count > /dev/null
}

@test "create_test_project is defined after sourcing test-helpers" {
  source "$TEST_HELPERS"
  declare -f create_test_project > /dev/null
}

@test "run_claude captures output into OUTPUT variable" {
  source "$TEST_HELPERS"
  run_claude "Does skill X auto-trigger on phrase Y?"
  [ -n "$OUTPUT" ]
}

@test "assert_contains exits 0 on match" {
  source "$TEST_HELPERS"
  run_claude "Does skill X auto-trigger on phrase Y?"
  run assert_contains "Yes"
  [ "$status" -eq 0 ]
}

@test "assert_contains exits 1 on mismatch" {
  source "$TEST_HELPERS"
  run_claude "Does skill X auto-trigger on phrase Y?"
  run assert_contains "This string will never appear in stub output XYZ_NEVER"
  [ "$status" -eq 1 ]
}

@test "assert_contains mismatch output contains diff-like info" {
  source "$TEST_HELPERS"
  run_claude "Does skill X auto-trigger on phrase Y?"
  run assert_contains "This string will never appear in stub output XYZ_NEVER"
  [[ "$output" == *"Expected"* ]] || [[ "$output" == *"not found"* ]] || [[ "$output" == *"XYZ_NEVER"* ]]
}

@test "assert_contains supports regex pattern" {
  source "$TEST_HELPERS"
  run_claude "Does skill X auto-trigger on phrase Y?"
  run assert_contains "skill.*trigger"
  [ "$status" -eq 0 ]
}

@test "assert_order exits 0 when substrings appear in order" {
  source "$TEST_HELPERS"
  OUTPUT="first step then second step then third step"
  run assert_order "first" "second" "third"
  [ "$status" -eq 0 ]
}

@test "assert_order exits 1 when substrings appear out of order" {
  source "$TEST_HELPERS"
  OUTPUT="second then first then third"
  run assert_order "first" "second"
  [ "$status" -eq 1 ]
}

@test "assert_count exits 0 when occurrence count matches" {
  source "$TEST_HELPERS"
  OUTPUT="apple banana apple cherry apple"
  run assert_count "apple" 3
  [ "$status" -eq 0 ]
}

@test "assert_count exits 1 when occurrence count does not match" {
  source "$TEST_HELPERS"
  OUTPUT="apple banana cherry"
  run assert_count "apple" 3
  [ "$status" -eq 1 ]
}

@test "create_test_project creates a directory with README.md and .claude/CLAUDE.md" {
  source "$TEST_HELPERS"
  project_dir=$(create_test_project)
  [ -d "$project_dir" ]
  [ -f "${project_dir}/README.md" ]
  [ -f "${project_dir}/.claude/CLAUDE.md" ]
  rm -rf "$project_dir"
}

@test "SKILL_TEST_CLAUDE_BIN env overrides claude binary" {
  source "$TEST_HELPERS"
  run_claude "test prompt"
  [[ "$OUTPUT" == *"stub"* ]] || [[ "$OUTPUT" == *"skill triggers"* ]]
}
