#!/usr/bin/env bats
# test_l4_samples.bats -- AC5: positive + negative sample tests per layer

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
RUNNER="${REPO_ROOT}/tests/claude-code/run-skill-tests.sh"
SAMPLES_DIR="${REPO_ROOT}/tests/claude-code/samples"

setup() {
  export SKILL_TEST_CLAUDE_BIN="${BATS_TEST_TMPDIR}/stub-claude.sh"
  cat > "$SKILL_TEST_CLAUDE_BIN" <<'EOF'
#!/usr/bin/env bash
# Stub claude: output "yes" for most queries, for integration emit a fake jsonl transcript
mode="${SKILL_TEST_MODE:-fast}"
if [ "$mode" = "integration" ]; then
  # Write a minimal valid jsonl to the transcript dir
  tmpdir="${SKILL_TEST_TMPDIR:-/tmp}"
  echo '{"type":"assistant","session_id":"stub-sess","usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"model":"claude-opus-4-5"}' > "${tmpdir}/stub-transcript.jsonl"
fi
echo "yes the skill description is trigger-only and correct"
EOF
  chmod +x "$SKILL_TEST_CLAUDE_BIN"
  export SKILL_TEST_TMPDIR="${BATS_TEST_TMPDIR}/transcripts"
  mkdir -p "$SKILL_TEST_TMPDIR"
}

teardown() {
  unset SKILL_TEST_CLAUDE_BIN SKILL_TEST_TMPDIR
}

# --- fast sample files exist ---

@test "fast PASS sample script exists" {
  [ -f "${SAMPLES_DIR}/fast-skill-description-lint.sh" ]
}

@test "fast FAIL sample script exists" {
  [ -f "${SAMPLES_DIR}/fast-intentional-fail.sh" ]
}

@test "integration PASS sample script exists" {
  [ -f "${SAMPLES_DIR}/integration-discover-minimal.sh" ]
}

@test "integration FAIL sample script exists" {
  [ -f "${SAMPLES_DIR}/integration-intentional-fail.sh" ]
}

# --- fast PASS sample exits 0 ---

@test "fast PASS sample exits 0 via runner" {
  run bash "$RUNNER" --test skill-description-lint
  [ "$status" -eq 0 ]
}

# --- fast FAIL sample exits 1 ---

@test "fast FAIL sample exits 1 via runner (negative test)" {
  run bash "$RUNNER" --test intentional-fail
  [ "$status" -eq 1 ]
}

# --- integration PASS sample exits 0 ---

@test "integration PASS sample exits 0 via runner" {
  run bash "$RUNNER" --integration --test discover-minimal
  [ "$status" -eq 0 ]
}

# --- integration FAIL sample exits 1 ---

@test "integration FAIL sample exits 1 via runner (negative test)" {
  run bash "$RUNNER" --integration --test intentional-fail
  [ "$status" -eq 1 ]
}

# --- runner output format ---

@test "runner prints PASS on success" {
  run bash "$RUNNER" --test skill-description-lint
  [[ "$output" == *"PASS"* ]]
}

@test "runner prints FAIL on failure" {
  run bash "$RUNNER" --test intentional-fail
  [[ "$output" == *"FAIL"* ]]
}

# --- fixture project exists ---

@test "minimal-project fixture has README.md" {
  [ -f "${REPO_ROOT}/tests/claude-code/fixtures/minimal-project/README.md" ]
}

@test "minimal-project fixture has .claude/CLAUDE.md stub" {
  [ -f "${REPO_ROOT}/tests/claude-code/fixtures/minimal-project/.claude/CLAUDE.md" ]
}
