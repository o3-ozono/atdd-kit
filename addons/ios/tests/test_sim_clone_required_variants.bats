#!/usr/bin/env bats

# Issue #1: Verify build_sim, build_run_sim, test_sim are in CLONE_REQUIRED_TOOLS
# and correctly routed through handle_xcodebuildmcp.

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

# --- AC2: 否定テスト — READONLY_TOOLS に含まれていない ---

@test "AC2.1: build_sim is NOT in READONLY_TOOLS" {
  ! grep -q '"mcp__XcodeBuildMCP__build_sim"' <(
    sed -n '/^READONLY_TOOLS=/,/^)/p' "$GUARD"
  )
}

@test "AC2.2: build_run_sim is NOT in READONLY_TOOLS" {
  ! grep -q '"mcp__XcodeBuildMCP__build_run_sim"' <(
    sed -n '/^READONLY_TOOLS=/,/^)/p' "$GUARD"
  )
}

@test "AC2.3: test_sim is NOT in READONLY_TOOLS" {
  ! grep -q '"mcp__XcodeBuildMCP__test_sim"' <(
    sed -n '/^READONLY_TOOLS=/,/^)/p' "$GUARD"
  )
}

# --- AC3: 初回呼び出し — DENY + session_set_defaults 案内 ---
# Each test uses a unique session_id to avoid setup_flag interference

@test "AC3.1: first build_sim call is DENY with session_set_defaults instruction" {
  result=$(run_guard "mcp__XcodeBuildMCP__build_sim" '{}' "session-ac3-1")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$context" == *"session_set_defaults"* ]]
}

@test "AC3.2: first build_run_sim call is DENY with session_set_defaults instruction" {
  result=$(run_guard "mcp__XcodeBuildMCP__build_run_sim" '{}' "session-ac3-2")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$context" == *"session_set_defaults"* ]]
}

@test "AC3.3: first test_sim call is DENY with session_set_defaults instruction" {
  result=$(run_guard "mcp__XcodeBuildMCP__test_sim" '{}' "session-ac3-3")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$context" == *"session_set_defaults"* ]]
}

# --- AC4: session_set_defaults 後 — ALLOW ---
# Each test: trigger clone via initial call, then session_set_defaults, then verify ALLOW

@test "AC4.1: build_sim is ALLOW after session_set_defaults" {
  # Step 1: initial call creates clone + setup_flag
  run_guard "mcp__XcodeBuildMCP__build" '{}' "session-ac4-1" > /dev/null 2>&1 || true
  # Step 2: session_set_defaults sets up the session
  run_guard "mcp__XcodeBuildMCP__session_set_defaults" \
    '{"simulatorName":"atdd-kit-clone","persist":false}' "session-ac4-1"
  # Step 3: build_sim should be ALLOW
  result=$(run_guard "mcp__XcodeBuildMCP__build_sim" '{}' "session-ac4-1")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC4.2: build_run_sim is ALLOW after session_set_defaults" {
  run_guard "mcp__XcodeBuildMCP__build" '{}' "session-ac4-2" > /dev/null 2>&1 || true
  run_guard "mcp__XcodeBuildMCP__session_set_defaults" \
    '{"simulatorName":"atdd-kit-clone","persist":false}' "session-ac4-2"
  result=$(run_guard "mcp__XcodeBuildMCP__build_run_sim" '{}' "session-ac4-2")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC4.3: test_sim is ALLOW after session_set_defaults" {
  run_guard "mcp__XcodeBuildMCP__build" '{}' "session-ac4-3" > /dev/null 2>&1 || true
  run_guard "mcp__XcodeBuildMCP__session_set_defaults" \
    '{"simulatorName":"atdd-kit-clone","persist":false}' "session-ac4-3"
  result=$(run_guard "mcp__XcodeBuildMCP__test_sim" '{}' "session-ac4-3")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}
