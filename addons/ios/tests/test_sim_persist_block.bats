#!/usr/bin/env bats

# AC4: persist: true is unconditionally DENIED for session_set_defaults
# and session_use_defaults_profile.

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"

  # Create mock xcrun
  export MOCK_BIN="${BATS_TMPDIR}/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
case "$*" in
  "simctl list devices available -j")
    cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}
JSON
    ;;
  simctl\ clone\ *) echo "CLONE-UUID-5678" ;;
  simctl\ boot\ *|simctl\ shutdown\ *|simctl\ delete\ *|simctl\ bootstatus\ *) ;;
  "simctl list devices -j")
    echo '{"devices":{}}'
    ;;
  *) echo "mock xcrun: $*" >&2 ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"
  export PATH="$MOCK_BIN:$PATH"

  # Pre-create golden marker so golden init is skipped
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"
}

teardown() {
  rm -rf "$SIM_SESSION_DIR" "$SIM_MARKER_DIR" "$MOCK_BIN"
}

# Helper: pipe hook JSON to guard and capture output
run_guard() {
  local tool_name="$1"
  local tool_input="$2"
  local session_id="${3:-test-session-persist}"
  printf '{"tool_name":"%s","tool_input":%s,"session_id":"%s"}' \
    "$tool_name" "$tool_input" "$session_id" \
    | bash "$GUARD"
}

# --- AC4.1-4.3: session_set_defaults with persist: true ---

@test "AC4.1: session_set_defaults with persist:true (boolean) is DENY" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_set_defaults" '{"simulatorName":"iPhone","persist":true}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC4.2: session_set_defaults with persist:\"true\" (string) is DENY" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_set_defaults" '{"simulatorName":"iPhone","persist":"true"}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC4.3: DENY reason mentions cross-session pollution" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_set_defaults" '{"persist":true}')
  reason=$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecisionReason')
  [[ "$reason" == *"cross-session"* ]]
}

# --- AC4.4-4.5: session_set_defaults without persist is allowed ---

@test "AC4.4: session_set_defaults with persist:false is ALLOW" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_set_defaults" '{"simulatorName":"iPhone","persist":false}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

@test "AC4.5: session_set_defaults without persist field is ALLOW" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_set_defaults" '{"simulatorName":"iPhone"}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

# --- AC4.6-4.8: session_use_defaults_profile with persist ---

@test "AC4.6: session_use_defaults_profile with persist:true is DENY" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_use_defaults_profile" '{"profile":"default","persist":true}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC4.7: session_use_defaults_profile with persist:\"true\" (string) is DENY" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_use_defaults_profile" '{"profile":"default","persist":"true"}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}

@test "AC4.8: session_use_defaults_profile with persist:false is ALLOW" {
  result=$(run_guard "mcp__XcodeBuildMCP__session_use_defaults_profile" '{"profile":"default","persist":false}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
}

# --- AC4.9-4.10: persist check is in PERSIST_CHECK_TOOLS array ---

@test "AC4.9: PERSIST_CHECK_TOOLS contains session_set_defaults" {
  grep -q '"mcp__XcodeBuildMCP__session_set_defaults"' <(
    sed -n '/^PERSIST_CHECK_TOOLS=/,/^)/p' "$GUARD"
  )
}

@test "AC4.10: PERSIST_CHECK_TOOLS contains session_use_defaults_profile" {
  grep -q '"mcp__XcodeBuildMCP__session_use_defaults_profile"' <(
    sed -n '/^PERSIST_CHECK_TOOLS=/,/^)/p' "$GUARD"
  )
}
