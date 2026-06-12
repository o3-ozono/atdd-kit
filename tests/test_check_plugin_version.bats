#!/usr/bin/env bats
# @covers: scripts/check-plugin-version.sh
setup() {
  export PLUGIN_ROOT="${BATS_TEST_TMPDIR}/plugin"
  export CACHE_DIR="${BATS_TEST_TMPDIR}/cache"
  # Point to a nonexistent file so RESTART_REQUIRED path is not triggered in legacy tests
  export MOCK_INSTALLED_JSON="${BATS_TEST_TMPDIR}/no_installed.json"
  export MOCK_PROJECT_PATH="/tmp/mock-project-$$"
  mkdir -p "$PLUGIN_ROOT"

  # Default: plugin at v0.1.0
  mkdir -p "${PLUGIN_ROOT}/.claude-plugin"
  echo '{"name":"atdd-kit","version":"0.1.0"}' > "${PLUGIN_ROOT}/.claude-plugin/plugin.json"

  # CHANGELOG with three versions (including 0.0.9 so cached=0.0.9 tests find the boundary)
  cat > "${PLUGIN_ROOT}/CHANGELOG.md" <<'CHANGELOG'
# Changelog

## [0.2.0] - 2026-04-10

### Added
- Plugin version notification in session-start
- CHANGELOG.md for tracking changes

## [0.1.0] - 2026-04-02

### Added
- Initial release

## [0.0.9] - 2026-04-01

### Added
- Pre-release
CHANGELOG
}

# Helper: write an installed_plugins.json fixture
# Usage: make_installed_json <json_path> <project_path> <version>
make_installed_json() {
  local json_path="$1" proj="$2" ver="$3"
  cat > "$json_path" <<JSON
{
  "version": 1,
  "plugins": {
    "atdd-kit@atdd-kit": [
      {
        "scope": "project",
        "projectPath": "${proj}",
        "installPath": "/Users/mock/.claude/plugins/atdd-kit/${ver}",
        "version": "${ver}",
        "installedAt": "2026-01-01T00:00:00Z"
      }
    ]
  }
}
JSON
}

# AC2: First run -- no cache exists
@test "AC2: outputs FIRST_RUN when no cache exists" {
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "FIRST_RUN" ]]
  [[ "${lines[1]}" == "0.1.0" ]]
}

@test "AC2: cache file is created on first run" {
  ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH" > /dev/null
  [[ -f "${CACHE_DIR}/atdd-kit.version" ]]
  [[ "$(cat "${CACHE_DIR}/atdd-kit.version")" == "0.1.0" ]]
}

# AC4: No update -- cache matches current version
@test "AC4: outputs NO_UPDATE when versions match" {
  mkdir -p "$CACHE_DIR"
  echo "0.1.0" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "NO_UPDATE" ]]
}

# AC3: Update detected -- cache differs from current
@test "AC3: outputs UPDATED when versions differ" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "UPDATED" ]]
  [[ "${lines[1]}" == "0.0.9" ]]
  [[ "${lines[2]}" == "0.1.0" ]]
}

# AC1 (Issue #75): structured summary output (5-line format)
@test "AC1 #75: UPDATED output has exactly 5 lines" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${#lines[@]}" -eq 5 ]]
}

@test "AC1 #75: line 4 is VERSIONS: <count>" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "${lines[3]}" =~ ^VERSIONS:\ [0-9]+ ]]
}

@test "AC1 #75: line 5 is BREAKING: <count>" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "${lines[4]}" =~ ^BREAKING:\ [0-9]+ ]]
}

@test "AC1 #75: no raw CHANGELOG bullets in output" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$output" != *"Initial release"* ]] || false
  [[ "$output" != *"### Added"* ]] || false
}

@test "AC3: cache is updated after detecting update" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH" > /dev/null
  [[ "$(cat "${CACHE_DIR}/atdd-kit.version")" == "0.1.0" ]]
}

# AC1: version is always readable from output
@test "AC1: outputs current version in all modes" {
  # FIRST_RUN mode
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$output" == *"0.1.0"* ]]

  # NO_UPDATE mode
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "${lines[0]}" == "NO_UPDATE" ]]
}

# AC2 #75: VERSIONS count accuracy
@test "AC2 #75: VERSIONS: 1 when one version between cached and current" {
  # plugin at 0.2.0, cached=0.1.0 -> only [0.2.0] counted = 1
  echo '{"name":"atdd-kit","version":"0.2.0"}' > "${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  mkdir -p "$CACHE_DIR"
  echo "0.1.0" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[3]}" == "VERSIONS: 1" ]]
}

@test "AC2 #75: VERSIONS: 2 when two versions between cached and current" {
  # plugin at 0.2.0, cached=0.0.9 -> [0.2.0] and [0.1.0] both counted = 2
  echo '{"name":"atdd-kit","version":"0.2.0"}' > "${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[3]}" == "VERSIONS: 2" ]]
}

# AC3 #75: BREAKING count accuracy
@test "AC3 #75: BREAKING: 0 when no BREAKING CHANGE in range" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[4]}" == "BREAKING: 0" ]]
}

@test "AC3 #75: BREAKING: 1 when one BREAKING CHANGE in range" {
  # Add BREAKING CHANGE to CHANGELOG
  cat > "${PLUGIN_ROOT}/CHANGELOG.md" <<'CHANGELOG'
# Changelog

## [0.1.0] - 2026-04-02

### Changed
- BREAKING CHANGE: removed old API

## [0.0.9] - 2026-04-01

### Added
- Initial release
CHANGELOG
  mkdir -p "$CACHE_DIR"
  echo "0.0.8" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[4]}" == "BREAKING: 1" ]]
}

@test "AC3 #75: BREAKING: 2 when two BREAKING CHANGE lines in range" {
  cat > "${PLUGIN_ROOT}/CHANGELOG.md" <<'CHANGELOG'
# Changelog

## [0.1.0] - 2026-04-02

### Changed
- BREAKING CHANGE: removed old API
- BREAKING CHANGE: renamed config key

## [0.0.9] - 2026-04-01

### Added
- Initial release
CHANGELOG
  mkdir -p "$CACHE_DIR"
  echo "0.0.8" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[4]}" == "BREAKING: 2" ]]
}

# AC4 #75: first 3 lines protocol compatibility
@test "AC4 #75: first 3 lines are UPDATED / old / new" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "UPDATED" ]]
  [[ "${lines[1]}" == "0.0.9" ]]
  [[ "${lines[2]}" == "0.1.0" ]]
}

# AC5 #75: CHANGELOG absent fallback
@test "AC5 #75: VERSIONS:0 BREAKING:0 when CHANGELOG.md absent" {
  rm -f "${PLUGIN_ROOT}/CHANGELOG.md"
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "UPDATED" ]]
  [[ "${lines[1]}" == "0.0.9" ]]
  [[ "${lines[2]}" == "0.1.0" ]]
  [[ "${lines[3]}" == "VERSIONS: 0" ]]
  [[ "${lines[4]}" == "BREAKING: 0" ]]
}

# ============================================================
# New tests: STALE_SESSION, RESTART_REQUIRED, CHANGELOG guard
# ============================================================

# AT-002: STALE_SESSION — loaded < cached, marker NOT updated
@test "AT-002: STALE_SESSION output when loaded version is older than cached" {
  mkdir -p "$CACHE_DIR"
  echo "3.12.0" > "${CACHE_DIR}/atdd-kit.version"  # cached is newer than CURRENT (0.1.0)
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "STALE_SESSION" ]]
  [[ "${lines[1]}" == "0.1.0" ]]
  [[ "${lines[2]}" == "3.12.0" ]]
}

@test "AT-002: STALE_SESSION does not update the marker file" {
  mkdir -p "$CACHE_DIR"
  echo "3.12.0" > "${CACHE_DIR}/atdd-kit.version"
  ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH" > /dev/null
  [[ "$(cat "${CACHE_DIR}/atdd-kit.version")" == "3.12.0" ]]
}

# AT-001: RESTART_REQUIRED — installed > loaded, marker NOT updated
@test "AT-001: RESTART_REQUIRED output when installed version is newer than loaded" {
  mkdir -p "$CACHE_DIR"
  echo "0.1.0" > "${CACHE_DIR}/atdd-kit.version"  # CACHED == CURRENT (would be NO_UPDATE), but installed is newer
  local installed_json="${BATS_TEST_TMPDIR}/installed.json"
  make_installed_json "$installed_json" "$MOCK_PROJECT_PATH" "3.12.0"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$installed_json" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "RESTART_REQUIRED" ]]
  [[ "${lines[1]}" == "0.1.0" ]]
  [[ "${lines[2]}" == "3.12.0" ]]
}

@test "AT-001: RESTART_REQUIRED does not update the marker file" {
  mkdir -p "$CACHE_DIR"
  echo "0.1.0" > "${CACHE_DIR}/atdd-kit.version"
  local installed_json="${BATS_TEST_TMPDIR}/installed.json"
  make_installed_json "$installed_json" "$MOCK_PROJECT_PATH" "3.12.0"
  ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$installed_json" "$MOCK_PROJECT_PATH" > /dev/null
  [[ "$(cat "${CACHE_DIR}/atdd-kit.version")" == "0.1.0" ]]
}

# AT-007: STALE_SESSION takes priority over RESTART_REQUIRED when both conditions are true
@test "AT-007: STALE_SESSION wins when both STALE and RESTART conditions hold simultaneously" {
  # CURRENT=0.1.0, CACHED=3.11.1 (STALE: 0.1.0 < 3.11.1), INSTALLED=3.12.0 (RESTART: 3.12.0 > 0.1.0)
  mkdir -p "$CACHE_DIR"
  echo "3.11.1" > "${CACHE_DIR}/atdd-kit.version"
  local installed_json="${BATS_TEST_TMPDIR}/installed.json"
  make_installed_json "$installed_json" "$MOCK_PROJECT_PATH" "3.12.0"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$installed_json" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "STALE_SESSION" ]]
}

# AT-006: Fallback — installed_plugins.json absent → conventional tokens work
@test "AT-006: FIRST_RUN is unaffected when installed_plugins.json is absent" {
  # No cache → FIRST_RUN regardless of absent installed JSON
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "/tmp/nonexistent_installed_$$.json" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "FIRST_RUN" ]]
}

@test "AT-006: NO_UPDATE is unaffected when installed_plugins.json is absent" {
  mkdir -p "$CACHE_DIR"
  echo "0.1.0" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "/tmp/nonexistent_installed_$$.json" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "NO_UPDATE" ]]
}

@test "AT-006: UPDATED is unaffected when installed_plugins.json is absent" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "/tmp/nonexistent_installed_$$.json" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "UPDATED" ]]
}

@test "AT-006: UPDATED is unaffected when installed_plugins.json is unparseable" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  local bad_json="${BATS_TEST_TMPDIR}/bad.json"
  echo "NOT VALID JSON {{{{" > "$bad_json"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$bad_json" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "UPDATED" ]]
}

@test "AT-006: NO_UPDATE is unaffected when installed_plugins.json has no matching projectPath entry" {
  mkdir -p "$CACHE_DIR"
  echo "0.1.0" > "${CACHE_DIR}/atdd-kit.version"
  local installed_json="${BATS_TEST_TMPDIR}/installed_other.json"
  make_installed_json "$installed_json" "/some/other/project" "3.12.0"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$installed_json" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "NO_UPDATE" ]]
}

# AT-004: CHANGELOG guard — VERSIONS: UNKNOWN when cached heading absent
@test "AT-004: VERSIONS: UNKNOWN when CACHED version heading is missing from CHANGELOG" {
  # CURRENT=0.1.0, CACHED=0.0.1 (not in CHANGELOG)
  mkdir -p "$CACHE_DIR"
  echo "0.0.1" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "UPDATED" ]]
  [[ "${lines[3]}" == "VERSIONS: UNKNOWN" ]]
}

@test "AT-004: VERSIONS is a number when CACHED heading exists in CHANGELOG" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$MOCK_INSTALLED_JSON" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[3]}" =~ ^VERSIONS:\ [0-9]+ ]]
}

# AT-008: Recovery — after restart loaded == installed, returns UPDATED or NO_UPDATE normally
@test "AT-008: after restart loaded matches installed, RESTART_REQUIRED is gone (NO_UPDATE)" {
  # CURRENT=3.12.0 (restarted), CACHED=3.12.0, INSTALLED=3.12.0 → NO_UPDATE
  echo '{"name":"atdd-kit","version":"3.12.0"}' > "${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  mkdir -p "$CACHE_DIR"
  echo "3.12.0" > "${CACHE_DIR}/atdd-kit.version"
  local installed_json="${BATS_TEST_TMPDIR}/installed.json"
  make_installed_json "$installed_json" "$MOCK_PROJECT_PATH" "3.12.0"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$installed_json" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "NO_UPDATE" ]]
}

@test "AT-008: after restart with marker at old version, UPDATED is shown correctly" {
  # CURRENT=3.12.0 (restarted), CACHED=3.11.1 (old marker), INSTALLED=3.12.0 → UPDATED
  echo '{"name":"atdd-kit","version":"3.12.0"}' > "${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  cat >> "${PLUGIN_ROOT}/CHANGELOG.md" <<'CL'

## [3.12.0] - 2026-06-01

### Added
- RESTART_REQUIRED detection

## [3.11.1] - 2026-05-01

### Added
- Previous version
CL
  mkdir -p "$CACHE_DIR"
  echo "3.11.1" > "${CACHE_DIR}/atdd-kit.version"
  local installed_json="${BATS_TEST_TMPDIR}/installed.json"
  make_installed_json "$installed_json" "$MOCK_PROJECT_PATH" "3.12.0"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" "$installed_json" "$MOCK_PROJECT_PATH"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "UPDATED" ]]
  [[ "${lines[1]}" == "3.11.1" ]]
  [[ "${lines[2]}" == "3.12.0" ]]
  # STALE_SESSION must NOT appear (current 3.12.0 is NOT < cached 3.11.1)
  [[ "${lines[0]}" != "STALE_SESSION" ]]
}

# AT-009: network-independent, local-only
# Static inspection: verify no external network calls (curl/wget/http/nc etc.) exist in the script.
# This guard detects future regressions if the script is modified.
@test "AT-009: check-plugin-version.sh has no external network calls (curl/wget/http/nc)" {
  # Check the entire script including comments and string literals
  # grep exits 1 when no lines match → test PASS
  run grep -nE '\b(curl|wget|nc |netcat|https?://|fetch |requests\.|urllib)' \
    scripts/check-plugin-version.sh
  [[ "$status" -eq 1 ]]
}

@test "AT-009: check-plugin-version.sh references only local files across all decision paths" {
  # Disallowed pattern: network-related tools must not appear in the script
  local script="scripts/check-plugin-version.sh"
  run grep -cE '\b(curl|wget|fetch|ssh|scp|rsync|nc |netcat|nslookup|dig|ping)\b' "$script"
  # grep -c outputs "0" when no lines match
  [[ "$output" == "0" ]]
}
