#!/usr/bin/env bats
# @covers: addons/ios/**
# AC6: Orphan clone cleanup — TTL-based detection and deletion of stale clones.

# Cross-platform date helper (BSD date on macOS, GNU date on Linux)
date_ago() {
  local offset="$1"  # e.g. "3H", "30M", "1H", "5M"
  local unit="${offset: -1}"
  local val="${offset%?}"
  if date -j +%s 2>/dev/null >&2; then
    date -j -v-"${val}${unit}" +%Y%m%dT%H%M%S
  else
    case "$unit" in
      H) date -d "${val} hours ago" +%Y%m%dT%H%M%S ;;
      M) date -d "${val} minutes ago" +%Y%m%dT%H%M%S ;;
    esac
  fi
}

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  export SIM_CLONE_PREFIX="atdd-kit-"
  export SIM_TTL_LOCAL=7200
  export SIM_TTL_CI=2400
  export SIM_NO_GOLDEN=0
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"

  export MOCK_BIN="${BATS_TMPDIR}/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  export XCRUN_LOG="${BATS_TMPDIR}/xcrun-calls-$$"
  : > "$XCRUN_LOG"
}

teardown() {
  rm -rf "$SIM_SESSION_DIR" "$SIM_MARKER_DIR" "$MOCK_BIN" "$XCRUN_LOG"
}

create_mock_with_stale_clones() {
  local stale_ts="$1"  # timestamp string for stale clone
  local fresh_ts="$2"  # timestamp string for fresh clone

  cat > "$MOCK_BIN/xcrun" <<MOCK
#!/bin/bash
echo "\$*" >> "$XCRUN_LOG"
case "\$*" in
  "simctl list devices available -j")
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    ;;
  "simctl list devices -j")
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"atdd-kit-${stale_ts}-stale123","udid":"STALE-UUID-1111","state":"Shutdown","isAvailable":true},{"name":"atdd-kit-${fresh_ts}-fresh456","udid":"FRESH-UUID-2222","state":"Booted","isAvailable":true}]}}'
    ;;
  simctl\ clone\ *) echo "CLONE-UUID-NEW" ;;
  simctl\ boot\ *|simctl\ shutdown\ *|simctl\ bootstatus\ *) ;;
  simctl\ delete\ *) ;;
  *) ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"
  export PATH="$MOCK_BIN:$PATH"
}

run_guard() {
  local tool_name="$1"
  local tool_input="${2:-\{\}}"
  local session_id="${3:-test-session-cleanup}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}

# --- AC6.1: Stale clone is deleted on next clone creation ---

@test "AC6.1: stale clone (past TTL) is shutdown+deleted during cleanup" {
  # Create stale timestamp (3 hours ago, TTL_LOCAL=7200s=2h)
  local stale_ts
  stale_ts=$(date_ago 3H)
  local fresh_ts
  fresh_ts=$(date_ago 30M)
  create_mock_with_stale_clones "$stale_ts" "$fresh_ts"

  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'

  grep -q "simctl shutdown STALE-UUID-1111" "$XCRUN_LOG"
  grep -q "simctl delete STALE-UUID-1111" "$XCRUN_LOG"
}

# --- AC6.2: Fresh clone is NOT deleted ---

@test "AC6.2: fresh clone (within TTL) is not deleted" {
  local stale_ts
  stale_ts=$(date_ago 3H)
  local fresh_ts
  fresh_ts=$(date_ago 30M)
  create_mock_with_stale_clones "$stale_ts" "$fresh_ts"

  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'

  ! grep -q "simctl delete FRESH-UUID-2222" "$XCRUN_LOG"
}

# --- AC6.3: Cleanup runs before new clone creation ---

@test "AC6.3: cleanup runs before new clone creation" {
  local stale_ts
  stale_ts=$(date_ago 3H)
  local fresh_ts
  fresh_ts=$(date_ago 30M)
  create_mock_with_stale_clones "$stale_ts" "$fresh_ts"

  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'

  # delete of stale should appear before clone of new
  local delete_line
  delete_line=$(grep -n "simctl delete STALE-UUID-1111" "$XCRUN_LOG" | head -1 | cut -d: -f1)
  local clone_line
  clone_line=$(grep -n "simctl clone" "$XCRUN_LOG" | head -1 | cut -d: -f1)
  [[ "$delete_line" -lt "$clone_line" ]]
}

# --- AC6.4: CI uses shorter TTL ---

@test "AC6.4: GITHUB_ACTIONS uses CI TTL (2400s)" {
  # Clone 1 hour ago (3600s) — should be stale with CI TTL (2400s) but fresh with local (7200s)
  local ci_stale_ts
  ci_stale_ts=$(date_ago 1H)
  local fresh_ts
  fresh_ts=$(date_ago 5M)

  create_mock_with_stale_clones "$ci_stale_ts" "$fresh_ts"
  export GITHUB_ACTIONS=true

  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'

  grep -q "simctl delete STALE-UUID-1111" "$XCRUN_LOG"
  unset GITHUB_ACTIONS
}

# --- AC6.5: Non-atdd-kit simulators are not touched ---

@test "AC6.5: only atdd-kit- prefixed clones are candidates for cleanup" {
  grep -q 'startswith(\$prefix)' "$GUARD"
}

# --- AC6.6: simctl delete is idempotent ---

@test "AC6.6: guard handles simctl delete failure gracefully (idempotent)" {
  # The guard uses || true after delete — verify pattern exists
  grep -q 'simctl delete.*|| true' "$GUARD"
}

# --- AC6.7: Clone name contains timestamp for TTL extraction ---

@test "AC6.7: clone name format embeds parseable timestamp" {
  grep -q 'date +%Y%m%dT%H%M%S' "$GUARD"
}

# --- AC6.8: cleanup_stale_clones function exists ---

@test "AC6.8: guard script defines cleanup_stale_clones function" {
  grep -q 'cleanup_stale_clones()' "$GUARD"
}

# --- AC6.9: TTL defaults are correct ---

@test "AC6.9: default TTL values are 7200 (local) and 2400 (CI)" {
  grep -q 'TTL_LOCAL.*7200' "$GUARD"
  grep -q 'TTL_CI.*2400' "$GUARD"
}
