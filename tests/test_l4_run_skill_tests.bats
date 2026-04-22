#!/usr/bin/env bats
# test_l4_run_skill_tests.bats -- AC2: integration runner

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
RUNNER="${REPO_ROOT}/tests/claude-code/run-skill-tests.sh"

setup() {
  export SKILL_TEST_CLAUDE_BIN="${BATS_TEST_TMPDIR}/stub-claude.sh"
  # Default stub: exits 0 with empty output
  cat > "$SKILL_TEST_CLAUDE_BIN" <<'EOF'
#!/usr/bin/env bash
echo "stub claude response"
EOF
  chmod +x "$SKILL_TEST_CLAUDE_BIN"
  export SKILL_TEST_TMPDIR="${BATS_TEST_TMPDIR}/transcripts"
  mkdir -p "$SKILL_TEST_TMPDIR"
}

teardown() {
  unset SKILL_TEST_CLAUDE_BIN SKILL_TEST_TMPDIR
}

@test "run-skill-tests.sh exists and is executable" {
  [ -x "$RUNNER" ]
}

@test "runner exits 3 with no args (usage error)" {
  run bash "$RUNNER"
  [ "$status" -eq 3 ]
}

@test "runner exits 3 for unknown test name (fast mode)" {
  run bash "$RUNNER" --test nonexistent-test-xyz
  [ "$status" -eq 3 ]
}

@test "runner exits 3 for unknown test name (integration mode)" {
  run bash "$RUNNER" --integration --test nonexistent-test-xyz
  [ "$status" -eq 3 ]
}

@test "runner exits 3 when claude binary not found" {
  SKILL_TEST_CLAUDE_BIN="/nonexistent/path/to/claude" run bash "$RUNNER" --test nonexistent-test
  [ "$status" -eq 3 ]
}

@test "runner shows usage when no args given" {
  run bash "$RUNNER"
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "runner accepts --test flag" {
  run bash "$RUNNER" --test nonexistent-test-xyz 2>&1
  [[ "$output" != *"unknown flag"* ]]
}

@test "runner accepts --integration flag" {
  run bash "$RUNNER" --integration --test nonexistent-test-xyz 2>&1
  [[ "$output" != *"unknown flag"* ]]
}

@test "runner accepts --verbose flag" {
  run bash "$RUNNER" --verbose --test nonexistent-test-xyz 2>&1
  [[ "$output" != *"unknown flag"* ]]
}

@test "runner in integration mode exits 3 when python3 not found" {
  # Override python3 binary name to a nonexistent command via SKILL_TEST_PYTHON3_BIN
  SKILL_TEST_PYTHON3_BIN="nonexistent-python3-xyz" run bash "$RUNNER" --integration --test nonexistent-test 2>&1
  [ "$status" -eq 3 ]
  [[ "$output" == *"python3"* ]]
}

@test "SKILL_TEST_TMPDIR env is respected (not HEADLESS_TEMP_DIR)" {
  # Verify env name separation from existing headless runner
  run env SKILL_TEST_TMPDIR="${BATS_TEST_TMPDIR}/custom" bash "$RUNNER" --test nonexistent 2>&1
  [[ "$output" != *"HEADLESS_TEMP_DIR"* ]]
}
