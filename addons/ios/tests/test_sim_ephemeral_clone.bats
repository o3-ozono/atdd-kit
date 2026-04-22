#!/usr/bin/env bats
# @covers: addons/ios/**
# AC1: Ephemeral clone lifecycle — clone creation, boot, session lock,
# duplicate request handling, clone name format.

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  export SIM_CLONE_PREFIX="atdd-kit-"
  export SIM_NO_GOLDEN=0
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"

  # Pre-create golden marker to skip golden init
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"

  export MOCK_BIN="${BATS_TMPDIR}/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  export XCRUN_LOG="${BATS_TMPDIR}/xcrun-calls-$$"
  : > "$XCRUN_LOG"

  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
echo "$*" >> "$XCRUN_LOG"
case "$*" in
  "simctl list devices available -j")
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    ;;
  simctl\ clone\ *) echo "CLONE-UUID-5678" ;;
  simctl\ boot\ *) ;;
  simctl\ shutdown\ *) ;;
  simctl\ bootstatus\ *) ;;
  "simctl list devices -j") echo '{"devices":{}}' ;;
  simctl\ delete\ *) ;;
  *) ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$SIM_SESSION_DIR" "$SIM_MARKER_DIR" "$MOCK_BIN" "$XCRUN_LOG"
}

run_guard() {
  local tool_name="$1"
  local tool_input="${2:-\{\}}"
  local session_id="${3:-test-session-clone1}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}

# --- AC1.1: Clone is created on first tool call ---

@test "AC1.1: simctl clone is called on first tool invocation" {
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  grep -q "simctl clone GOLDEN-UUID-1234" "$XCRUN_LOG"
}

# --- AC1.2: Clone is booted after creation ---

@test "AC1.2: clone is booted after creation" {
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  grep -q "simctl boot CLONE-UUID-5678" "$XCRUN_LOG"
}

# --- AC1.3: Lock file created with clone info ---

@test "AC1.3: session lock file contains clone UDID and name" {
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  [[ -f "$SIM_SESSION_DIR/test-session-clone1" ]]
  lock_content=$(cat "$SIM_SESSION_DIR/test-session-clone1")
  [[ "$lock_content" == CLONE-UUID-5678* ]]
  [[ "$lock_content" == *"atdd-kit-"* ]]
}

# --- AC1.4: Second call reuses existing clone ---

@test "AC1.4: second tool call reuses existing clone (no duplicate clone)" {
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  : > "$XCRUN_LOG"
  run_guard "mcp__ios-simulator__screenshot" '{}'
  ! grep -q "simctl clone" "$XCRUN_LOG"
}

# --- AC1.5: Clone name includes timestamp and session prefix ---

@test "AC1.5: clone name follows format atdd-kit-YYYYMMDDTHHMMSS-SESSION8" {
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  lock_content=$(cat "$SIM_SESSION_DIR/test-session-clone1")
  clone_name="${lock_content#*|}"
  # Check format: atdd-kit- followed by 15-char timestamp, dash, 8-char session
  [[ "$clone_name" =~ ^atdd-kit-[0-9]{8}T[0-9]{6}-test-ses$ ]]
}

# --- AC1.6: Different sessions get different clones ---

@test "AC1.6: different sessions get independent clones" {
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}' "session-aaa"
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}' "session-bbb"
  [[ -f "$SIM_SESSION_DIR/session-aaa" ]]
  [[ -f "$SIM_SESSION_DIR/session-bbb" ]]
}

# --- AC1.7: ensure_clone function exists in guard ---

@test "AC1.7: guard script defines ensure_clone function" {
  grep -q 'ensure_clone()' "$GUARD"
}
