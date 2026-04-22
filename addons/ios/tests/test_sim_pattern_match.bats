#!/usr/bin/env bats
# @covers: addons/ios/**
# AC2a: CLONE_REQUIRED via _sim pattern match.
# AC2b: CLONE_REQUIRED individual tools (screenshot, snapshot_ui, session_*).
# Tests pattern matching, edge cases, and clone failure.

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
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
  local session_id="${3:-test-session-pm}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}

# --- AC2a: _sim pattern match → CLONE_REQUIRED routing ---

@test "AC2a.1: build_sim matches _sim pattern (DENY + guidance on first call)" {
  result=$(run_guard "mcp__XcodeBuildMCP__build_sim" '{}' "s-2a1")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$context" == *"session_set_defaults"* ]]
}

@test "AC2a.2: test_sim matches _sim pattern" {
  result=$(run_guard "mcp__XcodeBuildMCP__test_sim" '{}' "s-2a2")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC2a.3: build_run_sim matches _sim pattern" {
  result=$(run_guard "mcp__XcodeBuildMCP__build_run_sim" '{}' "s-2a3")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC2a.4: install_app_sim matches _sim pattern" {
  result=$(run_guard "mcp__XcodeBuildMCP__install_app_sim" '{}' "s-2a4")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC2a.5: hypothetical future_feature_sim matches _sim pattern" {
  result=$(run_guard "mcp__XcodeBuildMCP__future_feature_sim" '{}' "s-2a5")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC2a.6: _sim suffix ALLOW after session_set_defaults" {
  # Step 1: initial call creates clone + setup_flag
  run_guard "mcp__XcodeBuildMCP__build_sim" '{}' "s-2a6" > /dev/null 2>&1 || true
  # Step 2: session_set_defaults
  run_guard "mcp__XcodeBuildMCP__session_set_defaults" \
    '{"simulatorName":"atdd-kit-clone","persist":false}' "s-2a6"
  # Step 3: build_sim should ALLOW
  result=$(run_guard "mcp__XcodeBuildMCP__build_sim" '{}' "s-2a6")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

# --- AC2a EDGE: pattern boundary tests ---

@test "AC2a.EDGE.1: boot_simulator does NOT match _sim pattern (fail-open ALLOW)" {
  result=$(run_guard "mcp__XcodeBuildMCP__boot_simulator" '{}' "s-edge1")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC2a.EDGE.2: sim_config does NOT match _sim pattern (fail-open ALLOW)" {
  result=$(run_guard "mcp__XcodeBuildMCP__sim_config" '{}' "s-edge2")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC2a.EDGE.3: record_sim_video does NOT match _sim pattern (fail-open ALLOW)" {
  result=$(run_guard "mcp__XcodeBuildMCP__record_sim_video" '{}' "s-edge3")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

# --- AC2b: Individual tools ---

@test "AC2b.1: screenshot is CLONE_REQUIRED (DENY + guidance)" {
  result=$(run_guard "mcp__XcodeBuildMCP__screenshot" '{}' "s-2b1")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$context" == *"session_set_defaults"* ]]
}

@test "AC2b.2: snapshot_ui is CLONE_REQUIRED" {
  result=$(run_guard "mcp__XcodeBuildMCP__snapshot_ui" '{}' "s-2b2")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC2b.3: session_set_defaults (persist:false) is CLONE_REQUIRED and ALLOWed" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_set_defaults" \
    '{"simulatorName":"clone","persist":false}' "s-2b3")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC2b.4: session_use_defaults_profile (persist:false) is CLONE_REQUIRED" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_use_defaults_profile" \
    '{"profile":"default","persist":false}' "s-2b4")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

# --- Clone creation failure ---

@test "AC2a.FAIL.1: clone creation failure returns DENY for _sim tool" {
  # Override mock to make clone fail
  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
case "$*" in
  "simctl list devices available -j")
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    ;;
  simctl\ clone\ *) exit 1 ;;
  simctl\ boot\ *|simctl\ shutdown\ *|simctl\ bootstatus\ *) ;;
  "simctl list devices -j") echo '{"devices":{}}' ;;
  simctl\ delete\ *) ;;
  *) ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"
  result=$(run_guard "mcp__XcodeBuildMCP__build_sim" '{}' "s-fail1")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  reason=$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecisionReason')
  [[ "$reason" == *"Failed to create simulator clone"* ]]
}
