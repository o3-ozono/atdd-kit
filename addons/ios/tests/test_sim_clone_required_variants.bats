#!/usr/bin/env bats

# Issue #1: Verify build_sim, build_run_sim, test_sim are in CLONE_REQUIRED_TOOLS
# and correctly routed through handle_xcodebuildmcp.

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"
  touch "$SIM_MARKER_DIR/atdd-kit-golden-initialized-iOS-18-0"

  export MOCK_BIN="${BATS_TMPDIR}/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
case "$*" in
  "simctl list devices available -j")
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    ;;
  simctl\ clone\ *) echo "CLONE-UUID-5678" ;;
  simctl\ boot\ *|simctl\ shutdown\ *|simctl\ bootstatus\ *) ;;
  "simctl list devices -j") echo '{"devices":{}}' ;;
  simctl\ delete\ *) ;;
  *) ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$SIM_SESSION_DIR" "$SIM_MARKER_DIR" "$MOCK_BIN"
}

run_guard() {
  local tool_name="$1"
  local tool_input="${2:-\{\}}"
  local session_id="${3:-test-session-variants}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}

# --- AC1: 静的検証 — CLONE_REQUIRED_TOOLS に 3 ツールが含まれる ---

@test "AC1.1: CLONE_REQUIRED_TOOLS contains build_sim" {
  grep -q '"mcp__XcodeBuildMCP__build_sim"' <(
    sed -n '/^CLONE_REQUIRED_TOOLS=/,/^)/p' "$GUARD"
  )
}

@test "AC1.2: CLONE_REQUIRED_TOOLS contains build_run_sim" {
  grep -q '"mcp__XcodeBuildMCP__build_run_sim"' <(
    sed -n '/^CLONE_REQUIRED_TOOLS=/,/^)/p' "$GUARD"
  )
}

@test "AC1.3: CLONE_REQUIRED_TOOLS contains test_sim" {
  grep -q '"mcp__XcodeBuildMCP__test_sim"' <(
    sed -n '/^CLONE_REQUIRED_TOOLS=/,/^)/p' "$GUARD"
  )
}
