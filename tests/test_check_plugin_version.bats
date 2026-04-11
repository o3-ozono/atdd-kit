#!/usr/bin/env bats

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

@test "AC3: CHANGELOG diff is included in output" {
  mkdir -p "$CACHE_DIR"
  echo "0.0.9" > "${CACHE_DIR}/atdd-kit.version"
  run ./scripts/check-plugin-version.sh "$PLUGIN_ROOT" "$CACHE_DIR"
  [[ "$output" == *"Initial release"* ]]
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
