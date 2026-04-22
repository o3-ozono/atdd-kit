#!/usr/bin/env bats
# @covers: scripts/check-plugin-version.sh
setup() {
  export PLUGIN_ROOT="${BATS_TEST_TMPDIR}/plugin"
  export CACHE_DIR="${BATS_TEST_TMPDIR}/cache"
  mkdir -p "$PLUGIN_ROOT"

  # Default: plugin at v0.1.0
  mkdir -p "${PLUGIN_ROOT}/.claude-plugin"
  echo '{"name":"atdd-kit","version":"0.1.0"}' > "${PLUGIN_ROOT}/.claude-plugin/plugin.json"

  # CHANGELOG with two versions
  cat > "${PLUGIN_ROOT}/CHANGELOG.md" <<'CHANGELOG'
# Changelog

## [0.2.0] - 2026-04-10

### Added
- Plugin version notification in session-start
- CHANGELOG.md for tracking changes

## [0.1.0] - 2026-04-02

### Added
- Initial release
CHANGELOG
}

# AC2: First run -- no cache exists
@test "AC2: outputs FIRST_RUN when no cache exists" {
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "FIRST_RUN" ]]
  [[ "${lines[1]}" == "0.1.0" ]]
}

@test "AC2: cache file is created on first run" {
  ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" > /dev/null
  [[ -f "${CACHE_DIR}/atdd-kit.version" ]]
  [[ "$(cat "${CACHE_DIR}/atdd-kit.version")" == "0.1.0" ]]
}

# AC4: No update -- cache matches current version
@test "AC4: outputs NO_UPDATE when versions match" {
  mkdir -p "$CACHE_DIR"
  echo "0.1.0" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "NO_UPDATE" ]]
}

# AC3: Update detected -- cache differs from current
@test "AC3: outputs UPDATED when versions differ" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "UPDATED" ]]
  [[ "${lines[1]}" == "0.0.9" ]]
  [[ "${lines[2]}" == "0.1.0" ]]
}

# AC1 (Issue #75): structured summary output (5-line format)
@test "AC1 #75: UPDATED output has exactly 5 lines" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$status" -eq 0 ]]
  [[ "${#lines[@]}" -eq 5 ]]
}

@test "AC1 #75: line 4 is VERSIONS: <count>" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "${lines[3]}" =~ ^VERSIONS:\ [0-9]+ ]]
}

@test "AC1 #75: line 5 is BREAKING: <count>" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "${lines[4]}" =~ ^BREAKING:\ [0-9]+ ]]
}

@test "AC1 #75: no raw CHANGELOG bullets in output" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$output" != *"Initial release"* ]] || false
  [[ "$output" != *"### Added"* ]] || false
}

@test "AC3: cache is updated after detecting update" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR" > /dev/null
  [[ "$(cat "${CACHE_DIR}/atdd-kit.version")" == "0.1.0" ]]
}

# AC1: version is always readable from output
@test "AC1: outputs current version in all modes" {
  # FIRST_RUN mode
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$output" == *"0.1.0"* ]]

  # NO_UPDATE mode
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "${lines[0]}" == "NO_UPDATE" ]]
}

# AC2 #75: VERSIONS count accuracy
@test "AC2 #75: VERSIONS: 1 when one version between cached and current" {
  # plugin at 0.2.0, cached=0.1.0 -> only [0.2.0] counted = 1
  echo '{"name":"atdd-kit","version":"0.2.0"}' > "${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  mkdir -p "$CACHE_DIR"
  echo "0.1.0" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$status" -eq 0 ]]
  [[ "${lines[3]}" == "VERSIONS: 1" ]]
}

@test "AC2 #75: VERSIONS: 2 when two versions between cached and current" {
  # plugin at 0.2.0, cached=0.0.9 -> [0.2.0] and [0.1.0] both counted = 2
  echo '{"name":"atdd-kit","version":"0.2.0"}' > "${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$status" -eq 0 ]]
  [[ "${lines[3]}" == "VERSIONS: 2" ]]
}

# AC3 #75: BREAKING count accuracy
@test "AC3 #75: BREAKING: 0 when no BREAKING CHANGE in range" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
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
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
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
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$status" -eq 0 ]]
  [[ "${lines[4]}" == "BREAKING: 2" ]]
}

# AC4 #75: first 3 lines protocol compatibility
@test "AC4 #75: first 3 lines are UPDATED / old / new" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
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
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "UPDATED" ]]
  [[ "${lines[1]}" == "0.0.9" ]]
  [[ "${lines[2]}" == "0.1.0" ]]
  [[ "${lines[3]}" == "VERSIONS: 0" ]]
  [[ "${lines[4]}" == "BREAKING: 0" ]]
}
