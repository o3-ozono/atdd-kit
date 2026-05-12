#!/usr/bin/env bats
# @covers: scripts/run-skill-e2e.sh
# Unit Test for the path-based impact mapping in scripts/run-skill-e2e.sh (#222).
# Verifies: AT-002 / AT-003 / AT-004 / AT-008 / AT-009 / AT-010
# from docs/issues/222-skill-test-redesign/acceptance-tests.md.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
RUNNER="${REPO_ROOT}/scripts/run-skill-e2e.sh"

setup() {
  export E2E_REPO_ROOT="${BATS_TEST_TMPDIR}/fake-repo"
  mkdir -p "${E2E_REPO_ROOT}/skills/skill-a"
  mkdir -p "${E2E_REPO_ROOT}/skills/skill-b"
  mkdir -p "${E2E_REPO_ROOT}/tests/e2e"
  mkdir -p "${E2E_REPO_ROOT}/rules"
  mkdir -p "${E2E_REPO_ROOT}/templates/docs/issues"
  mkdir -p "${E2E_REPO_ROOT}/docs/methodology"
  mkdir -p "${E2E_REPO_ROOT}/lib"
  cat > "${E2E_REPO_ROOT}/skills/skill-a/SKILL.md" <<'EOF'
# skill-a
Uses lib/shared.sh for helpers.
EOF
  cat > "${E2E_REPO_ROOT}/skills/skill-b/SKILL.md" <<'EOF'
# skill-b
No external deps.
EOF
  : > "${E2E_REPO_ROOT}/tests/e2e/skill-a.bats"
  : > "${E2E_REPO_ROOT}/tests/e2e/skill-b.bats"
}

teardown() {
  unset E2E_REPO_ROOT
}

# AT-002: skill change -> only that skill's e2e
@test "AT-002: skills/skill-a change resolves only tests/e2e/skill-a.bats" {
  run bash "$RUNNER" --changed-files skills/skill-a/SKILL.md --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "tests/e2e/skill-a.bats"
  ! echo "$output" | grep -q "tests/e2e/skill-b.bats"
}

# AT-003: shared assets (rules/) -> ALL e2e
@test "AT-003: rules/ change resolves ALL tests/e2e/*.bats" {
  run bash "$RUNNER" --changed-files rules/atdd-kit.md --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "tests/e2e/skill-a.bats"
  echo "$output" | grep -q "tests/e2e/skill-b.bats"
}

# AT-003 variant: templates/ -> ALL
@test "AT-003 variant: templates/ change resolves ALL" {
  run bash "$RUNNER" --changed-files templates/docs/issues/prd.md --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "tests/e2e/skill-a.bats"
  echo "$output" | grep -q "tests/e2e/skill-b.bats"
}

# AT-003 variant: docs/methodology/ -> ALL
@test "AT-003 variant: docs/methodology/ change resolves ALL" {
  run bash "$RUNNER" --changed-files docs/methodology/atdd-guide.md --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "tests/e2e/skill-a.bats"
  echo "$output" | grep -q "tests/e2e/skill-b.bats"
}

# AT-010: lib/ change -> only skill citing it
@test "AT-010: lib/<file> change resolves only skills whose SKILL.md cites it" {
  run bash "$RUNNER" --changed-files lib/shared.sh --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "tests/e2e/skill-a.bats"
  ! echo "$output" | grep -q "tests/e2e/skill-b.bats"
}

# AT-010 variant: unrelated -> no targets
@test "AT-010 variant: unrelated path resolves no targets" {
  run bash "$RUNNER" --changed-files README.md --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "summary: PASS (0/0)"
}

# AT-004 + AT-009: log fields including git_sha matching HEAD
@test "AT-004 + AT-009: log contains run-id / git_sha / timestamp / targets / mode" {
  (cd "$E2E_REPO_ROOT" && git init -q && git -c user.email=a@b -c user.name=t commit --allow-empty -q -m init)
  expected_sha="$(git -C "$E2E_REPO_ROOT" rev-parse HEAD)"
  LOG_DIR="${BATS_TEST_TMPDIR}/logs"
  run bash "$RUNNER" --changed-files skills/skill-a/SKILL.md --dry-run --log-dir "$LOG_DIR"
  [ "$status" -eq 0 ]
  log_file="$(find "$LOG_DIR" -name '*.log' -type f | head -1)"
  [ -n "$log_file" ]
  grep -q "^run-id: " "$log_file"
  grep -qE "^git_sha: ${expected_sha}$" "$log_file"
  grep -qE "^timestamp: [0-9]{4}-[0-9]{2}-[0-9]{2}T" "$log_file"
  grep -q "^mode: dry-run" "$log_file"
  grep -q "tests/e2e/skill-a.bats" "$log_file"
}

# AT-008: runner has no evals/skill-creator dependency
@test "AT-008: runner source has no evals/skill-creator dependency" {
  ! grep -nE "evals/evals\.json|skill-creator" "$RUNNER"
}

# Usage error: missing both flags -> exit 3
@test "usage: missing --changed-files and --all -> exit 3" {
  run bash "$RUNNER"
  [ "$status" -eq 3 ]
}

# --all 路径: 全 e2e 列挙
@test "--all resolves every tests/e2e/*.bats" {
  run bash "$RUNNER" --all --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "tests/e2e/skill-a.bats"
  echo "$output" | grep -q "tests/e2e/skill-b.bats"
}
