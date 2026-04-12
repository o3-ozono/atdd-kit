#!/usr/bin/env bats

# AC1: Fail-Open Guard — unknown tools get immediate ALLOW.
# AC4: DENY erase_sims for golden image protection.
# AC5: DENY check runs before session_id check.
# AC6: READONLY_TOOLS removed, set -u safe.

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  export SIM_TTL_LOCAL=7200
  export SIM_TTL_CI=2400
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
  "simctl list devices -j")
    echo '{"devices":{}}'
    ;;
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
  local default_input='{}'
  local tool_input="${2:-$default_input}"
  local session_id="${3-test-session-abc123}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}

# --- AC1: Fail-open default — unknown tools get ALLOW ---

@test "AC1.1: unknown XcodeBuildMCP tool gets immediate ALLOW" {
  result=$(run_guard "mcp__XcodeBuildMCP__unknown_future_tool")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC1.2: unknown ios-simulator tool gets immediate ALLOW" {
  result=$(run_guard "mcp__ios-simulator__unknown_future_tool")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC1.3: former READONLY tool (list_schemes) gets immediate ALLOW under fail-open" {
  result=$(run_guard "mcp__XcodeBuildMCP__list_schemes")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC1.4: former READONLY tool (get_booted_sim_id) gets immediate ALLOW" {
  result=$(run_guard "mcp__ios-simulator__get_booted_sim_id")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC1.5: non-sim XcodeBuildMCP tool (build_device) gets immediate ALLOW" {
  result=$(run_guard "mcp__XcodeBuildMCP__build_device")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC1.6: debug tool (debug_continue) gets immediate ALLOW (fail-open)" {
  result=$(run_guard "mcp__XcodeBuildMCP__debug_continue")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

# --- AC4: DENY erase_sims ---

@test "AC4.1: erase_sims is DENY" {
  result=$(run_guard "mcp__XcodeBuildMCP__erase_sims")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC4.2: erase_sims DENY reason mentions golden image" {
  result=$(run_guard "mcp__XcodeBuildMCP__erase_sims")
  reason=$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecisionReason')
  [[ "$reason" == *"golden image"* ]]
}

# --- AC5: DENY check runs before session_id check ---

@test "AC5.1: erase_sims with empty session_id is still DENY" {
  result=$(run_guard "mcp__XcodeBuildMCP__erase_sims" '{}' "")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC5.2: non-DENY tool with empty session_id is ALLOW" {
  result=$(run_guard "mcp__XcodeBuildMCP__build_device" '{}' "")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

# --- AC6: READONLY_TOOLS removal + set -u safety ---

@test "AC6.1: guard script does NOT contain READONLY_TOOLS array" {
  ! grep -q 'READONLY_TOOLS=' "$GUARD"
}

@test "AC6.2: guard script does NOT reference READONLY_TOOLS[@]" {
  ! grep -q 'READONLY_TOOLS\[@\]' "$GUARD"
}

@test "AC6.3: no unbound variable error with CLONE_REQUIRED tool" {
  result=$(run_guard "mcp__XcodeBuildMCP__build_sim" '{}' "test-session-ac6-3")
  echo "$result" | jq -e '.hookSpecificOutput' > /dev/null
}

@test "AC6.4: no unbound variable error with unknown tool" {
  result=$(run_guard "mcp__XcodeBuildMCP__unknown_tool")
  echo "$result" | jq -e '.hookSpecificOutput' > /dev/null
}

@test "AC6.5: guard has is_xcode_clone_required function" {
  grep -q 'is_xcode_clone_required()' "$GUARD"
}

# --- Regression: maintained behaviors ---

@test "REG.1: addon.yml hooks matcher catches XcodeBuildMCP tools" {
  grep -q 'mcp__XcodeBuildMCP__' addons/ios/addon.yml
}

@test "REG.2: addon.yml hooks matcher catches ios-simulator tools" {
  grep -q 'mcp__ios-simulator__' addons/ios/addon.yml
}

@test "REG.3: addon.yml hooks timeout is 90 seconds" {
  grep -q 'timeout: 90' addons/ios/addon.yml
}

@test "REG.4: empty session_id for non-DENY tool passes through as ALLOW" {
  result=$(echo '{"tool_name":"mcp__XcodeBuildMCP__list_schemes","tool_input":{},"session_id":""}' | bash "$GUARD")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "REG.5: guard script exists" {
  [[ -f "$GUARD" ]]
}
