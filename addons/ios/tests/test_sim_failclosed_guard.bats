#!/usr/bin/env bats

# AC3: Fail-Closed Guard — all XcodeBuildMCP/ios-simulator tools are captured,
# only allowlisted tools pass, unknown tools are DENIED.

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  export SIM_TTL_LOCAL=7200
  export SIM_TTL_CI=2400
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"

  # Create mock xcrun that simulates simctl behavior
  export MOCK_BIN="${BATS_TMPDIR}/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
# Mock xcrun for testing — returns canned responses
case "$*" in
  "simctl list devices available -j")
    cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}
JSON
    ;;
  simctl\ clone\ *)
    echo "CLONE-UUID-5678"
    ;;
  simctl\ boot\ *)
    ;;
  simctl\ shutdown\ *)
    ;;
  simctl\ delete\ *)
    ;;
  simctl\ bootstatus\ *)
    ;;
  "simctl list devices -j")
    cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true}]}}
JSON
    ;;
  *)
    echo "mock xcrun: unhandled: $*" >&2
    ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"

  # Also mock jq if needed (it should be available on most systems)
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$SIM_SESSION_DIR" "$SIM_MARKER_DIR" "$MOCK_BIN"
}

# Helper: pipe hook JSON to guard and capture output
run_guard() {
  local tool_name="$1"
  local tool_input="${2:-{}}"
  local session_id="${3:-test-session-abc123}"
  echo "{\"tool_name\":\"${tool_name}\",\"tool_input\":${tool_input},\"session_id\":\"${session_id}\"}" \
    | bash "$GUARD"
}

# --- AC3.1: addon.yml uses catch-all matchers ---

@test "AC3.1: addon.yml hooks matcher catches XcodeBuildMCP tools" {
  grep -q 'mcp__XcodeBuildMCP__' addons/ios/addon.yml
}

@test "AC3.2: addon.yml hooks matcher catches ios-simulator tools" {
  grep -q 'mcp__ios-simulator__' addons/ios/addon.yml
}

@test "AC3.3: addon.yml hooks timeout is 90 seconds" {
  grep -q 'timeout: 90' addons/ios/addon.yml
}

# --- AC3.4-3.8: READONLY_TOOLS are immediately ALLOWed ---

@test "AC3.4: list_schemes is ALLOW (readonly)" {
  result=$(run_guard "mcp__XcodeBuildMCP__list_schemes")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC3.5: discover_projects is ALLOW (readonly)" {
  result=$(run_guard "mcp__XcodeBuildMCP__discover_projects")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC3.6: session_show_defaults is ALLOW (readonly)" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_show_defaults")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC3.7: session_clear_defaults is ALLOW (readonly)" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_clear_defaults")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC3.8: get_booted_simulators is ALLOW (readonly)" {
  result=$(run_guard "mcp__ios-simulator__get_booted_simulators")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

# --- AC3.9-3.11: Unknown tools are DENIED (fail-closed) ---

@test "AC3.9: unknown XcodeBuildMCP tool is DENY" {
  result=$(run_guard "mcp__XcodeBuildMCP__unknown_new_tool")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC3.10: unknown ios-simulator tool is DENY" {
  result=$(run_guard "mcp__ios-simulator__unknown_new_tool")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC3.11: DENY message includes tool name for unknown tool" {
  result=$(run_guard "mcp__XcodeBuildMCP__unknown_new_tool")
  reason=$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecisionReason')
  [[ "$reason" == *"unknown_new_tool"* ]]
}

# --- AC3.12-3.15: Bypass regression tests (from Issue #150 V1-V5) ---

@test "AC3.12: session_set_defaults is in CLONE_REQUIRED (not READONLY — V1/V2 bypass fix)" {
  # session_set_defaults must NOT be in READONLY_TOOLS (that would bypass guard)
  ! grep -q '"mcp__XcodeBuildMCP__session_set_defaults"' <(
    sed -n '/^READONLY_TOOLS=/,/^)/p' "$GUARD"
  )
  # Must be in CLONE_REQUIRED_TOOLS
  grep -q '"mcp__XcodeBuildMCP__session_set_defaults"' <(
    sed -n '/^CLONE_REQUIRED_TOOLS=/,/^)/p' "$GUARD"
  )
}

@test "AC3.13: session_use_defaults_profile is in CLONE_REQUIRED (not READONLY — V4 bypass fix)" {
  ! grep -q '"mcp__XcodeBuildMCP__session_use_defaults_profile"' <(
    sed -n '/^READONLY_TOOLS=/,/^)/p' "$GUARD"
  )
  grep -q '"mcp__XcodeBuildMCP__session_use_defaults_profile"' <(
    sed -n '/^CLONE_REQUIRED_TOOLS=/,/^)/p' "$GUARD"
  )
}

@test "AC3.14: no regex negative lookahead in addon.yml matchers" {
  # The old pattern used (?!session_|list_|...) — new design must not
  ! grep -q '(?!' addons/ios/addon.yml
}

@test "AC3.15: guard script contains READONLY_TOOLS array" {
  grep -q 'READONLY_TOOLS=' "$GUARD"
}

# --- AC3.16-3.17: No session_id passthrough ---

@test "AC3.16: empty session_id passes through (allow)" {
  result=$(echo '{"tool_name":"mcp__XcodeBuildMCP__build","tool_input":{},"session_id":""}' | bash "$GUARD")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC3.17: guard script is executable" {
  [[ -f "$GUARD" ]]
}
