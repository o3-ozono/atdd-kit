#!/usr/bin/env bats
# @covers: scripts/bats_runner.sh

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
RUNNER="$REPO_ROOT/scripts/bats_runner.sh"

setup() {
  TMPDIR_WORK="$(mktemp -d)"
  export TMPDIR_WORK
  export CALL_LOG="${TMPDIR_WORK}/called_bats.log"

  mkdir -p "${TMPDIR_WORK}/config" \
            "${TMPDIR_WORK}/tests" \
            "${TMPDIR_WORK}/addons/ios/tests"

  # Minimal impact_rules.yml
  cat > "${TMPDIR_WORK}/config/impact_rules.yml" << 'YAML'
rules:
  - path: lib/**
    bats: "@covers lib"
  - path: scripts/**
    bats: "@covers scripts"
YAML

  # Dummy BATS that record which file was called
  _mk_dummy() {
    local path="$1" covers="$2" log="$3"
    local bname; bname="$(basename "$path")"
    printf '#!/usr/bin/env bats\n# @covers: %s\n@test "dummy" { echo "%s" >> "%s"; true; }\n' \
      "$covers" "$bname" "$log" > "$path"
    chmod +x "$path"
  }

  _mk_dummy "${TMPDIR_WORK}/tests/test_lib.bats"            "lib/spec_check.sh"   "$CALL_LOG"
  _mk_dummy "${TMPDIR_WORK}/tests/test_scripts.bats"        "scripts/impact_map.sh" "$CALL_LOG"
  _mk_dummy "${TMPDIR_WORK}/tests/test_hooks.bats"          "hooks/**"            "$CALL_LOG"
  _mk_dummy "${TMPDIR_WORK}/addons/ios/tests/test_ios.bats" "addons/ios/**"       "$CALL_LOG"

  # Mock impact_map.sh factory — writes mock script that emits given output/stderr/exit
  # Usage: mk_mock_impact <exit_code> <stdout_content> <stderr_content>
  mk_mock_impact() {
    local exit_code="$1" stdout="$2" stderr="$3"
    local mock_path="${TMPDIR_WORK}/mock_impact_map.sh"
    printf '#!/usr/bin/env bash\nprintf "%%s" %q >&2\nprintf "%%s" %q\nexit %d\n' \
      "$stderr" "$stdout" "$exit_code" > "$mock_path"
    chmod +x "$mock_path"
    export _BATS_RUNNER_IMPACT_MAP_OVERRIDE="$mock_path"
  }
  export -f mk_mock_impact
}

teardown() {
  unset _BATS_RUNNER_IMPACT_MAP_OVERRIDE
  rm -rf "$TMPDIR_WORK"
}

# -----------------------------------------------------------------------
# AC3: --all runs every BATS
# -----------------------------------------------------------------------
@test "bats_runner --all: runs all BATS files including iOS addon" {
  run "$RUNNER" --all --repo "$TMPDIR_WORK"
  [ "$status" -eq 0 ]
  [ -f "$CALL_LOG" ]
  grep -q "test_lib.bats"     "$CALL_LOG"
  grep -q "test_scripts.bats" "$CALL_LOG"
  grep -q "test_hooks.bats"   "$CALL_LOG"
  grep -q "test_ios.bats"     "$CALL_LOG"
}

# -----------------------------------------------------------------------
# AC5: no-diff exits 0 without invoking bats
# -----------------------------------------------------------------------
@test "bats_runner --impact: empty impact map output exits 0 with no-affected message" {
  # Mock: impact_map returns empty stdout (no diff)
  mock_path="${TMPDIR_WORK}/mock_impact_empty.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$mock_path"
  chmod +x "$mock_path"
  export _BATS_RUNNER_IMPACT_MAP_OVERRIDE="$mock_path"

  run "$RUNNER" --impact --base HEAD --repo "$TMPDIR_WORK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no affected BATS"* ]]
  [ ! -f "$CALL_LOG" ]
}

# -----------------------------------------------------------------------
# AC2: impact run for targeted change
# -----------------------------------------------------------------------
@test "bats_runner --impact: runs only BATS returned by impact_map" {
  # Mock: impact_map returns only test_lib.bats
  mock_path="${TMPDIR_WORK}/mock_impact_lib.sh"
  lib_bats="${TMPDIR_WORK}/tests/test_lib.bats"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\nexit 0\n' "$lib_bats" > "$mock_path"
  chmod +x "$mock_path"
  export _BATS_RUNNER_IMPACT_MAP_OVERRIDE="$mock_path"

  run "$RUNNER" --impact --base HEAD --repo "$TMPDIR_WORK"
  [ "$status" -eq 0 ]

  [ -f "$CALL_LOG" ]
  grep -q "test_lib.bats" "$CALL_LOG"
  ! grep -q "test_scripts.bats" "$CALL_LOG"
  ! grep -q "test_hooks.bats" "$CALL_LOG"
}

# -----------------------------------------------------------------------
# AC4: FALLBACK triggers full run
# -----------------------------------------------------------------------
@test "bats_runner --impact: FALLBACK in impact_map stderr triggers full run" {
  # Mock: impact_map emits FALLBACK: on stderr, stdout empty
  mock_path="${TMPDIR_WORK}/mock_impact_fallback.sh"
  printf '#!/usr/bin/env bash\nprintf "FALLBACK: unmatched files:\\n" >&2\nexit 0\n' > "$mock_path"
  chmod +x "$mock_path"
  export _BATS_RUNNER_IMPACT_MAP_OVERRIDE="$mock_path"

  run "$RUNNER" --impact --base HEAD --repo "$TMPDIR_WORK"
  [ "$status" -eq 0 ]

  [ -f "$CALL_LOG" ]
  grep -q "test_lib.bats"     "$CALL_LOG"
  grep -q "test_scripts.bats" "$CALL_LOG"
  grep -q "test_hooks.bats"   "$CALL_LOG"
}

# -----------------------------------------------------------------------
# AC6: invalid base ref exits non-zero
# -----------------------------------------------------------------------
@test "bats_runner --impact: impact_map non-zero exit propagates as error" {
  # Mock: impact_map exits with error
  mock_path="${TMPDIR_WORK}/mock_impact_error.sh"
  printf '#!/usr/bin/env bash\nprintf "ERROR: failed to diff against nonexistent-sha\\n" >&2\nexit 1\n' > "$mock_path"
  chmod +x "$mock_path"
  export _BATS_RUNNER_IMPACT_MAP_OVERRIDE="$mock_path"

  run "$RUNNER" --impact --base nonexistent-sha --repo "$TMPDIR_WORK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"failed"* ]] \
    || [[ "$output" == *"error"* ]] \
    || [[ "$output" == *"Error"* ]] \
    || [[ "$output" == *"nonexistent"* ]]
}
