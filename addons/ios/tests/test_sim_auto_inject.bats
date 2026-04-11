#!/usr/bin/env bats

# AC5: Automatic simulator name/UDID injection —
# XcodeBuildMCP: DENY+instruction on first build, ios-simulator: updatedInput udid injection.

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  export SIM_NO_GOLDEN=0
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"

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
  local session_id="${3:-test-session-inject}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}

# --- AC5.1: First XcodeBuildMCP build DENY with session_set_defaults instruction ---

@test "AC5.1: first build call is DENY with session_set_defaults instruction" {
  result=$(run_guard "mcp__XcodeBuildMCP__build" '{}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$context" == *"session_set_defaults"* ]]
  [[ "$context" == *"persist: false"* || "$context" == *"persist"* ]]
}

# --- AC5.2: After session_set_defaults, build is ALLOWed ---

@test "AC5.2: build is ALLOW after session_set_defaults has been called" {
  # First: trigger clone creation via a build attempt
  run_guard "mcp__XcodeBuildMCP__build" '{}' > /dev/null 2>&1 || true
  # Then: call session_set_defaults (this sets the setup flag)
  run_guard "mcp__XcodeBuildMCP__session_set_defaults" '{"simulatorName":"atdd-kit-clone","persist":false}'
  # Now: build should be allowed
  result=$(run_guard "mcp__XcodeBuildMCP__build" '{}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

# --- AC5.3: ios-simulator tools get udid injected via updatedInput ---

@test "AC5.3: ios-simulator tap gets udid injected in updatedInput" {
  result=$(run_guard "mcp__ios-simulator__tap" '{"x":100,"y":200}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
  udid=$(echo "$result" | jq -r '.hookSpecificOutput.updatedInput.udid')
  [[ "$udid" == "CLONE-UUID-5678" ]]
}

# --- AC5.4: ios-simulator preserves original input fields ---

@test "AC5.4: udid injection preserves original tool_input fields" {
  result=$(run_guard "mcp__ios-simulator__tap" '{"x":100,"y":200}')
  echo "$result" | jq -e '.hookSpecificOutput.updatedInput.x == 100'
  echo "$result" | jq -e '.hookSpecificOutput.updatedInput.y == 200'
}

# --- AC5.5: DENY instruction mentions clone name ---

@test "AC5.5: DENY additionalContext includes clone name" {
  result=$(run_guard "mcp__XcodeBuildMCP__build" '{}')
  context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$context" == *"atdd-kit-"* ]]
}

# --- AC5.6: session_set_defaults itself is ALLOWed (creates setup flag) ---

@test "AC5.6: session_set_defaults is ALLOW and creates setup flag" {
  # First trigger clone creation
  run_guard "mcp__XcodeBuildMCP__build" '{}' > /dev/null 2>&1 || true
  result=$(run_guard "mcp__XcodeBuildMCP__session_set_defaults" '{"simulatorName":"clone","persist":false}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
  [[ -f "$SIM_SESSION_DIR/test-session-inject.setup" ]]
}
