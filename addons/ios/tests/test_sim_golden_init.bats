#!/usr/bin/env bats

# AC2: Golden image lazy initialization — first boot, marker creation,
# skip on subsequent calls, error when runtime not found.

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"

  export MOCK_BIN="${BATS_TMPDIR}/mock-bin-$$"
  mkdir -p "$MOCK_BIN"

  # Track xcrun calls — exported so mock subprocess can see it
  export XCRUN_LOG="${BATS_TMPDIR}/xcrun-calls-$$"
  : > "$XCRUN_LOG"

  # SIM_NO_GOLDEN — exported so mock subprocess can see it
  export SIM_NO_GOLDEN="${SIM_NO_GOLDEN:-0}"

  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
echo "$*" >> "$XCRUN_LOG"
case "$*" in
  "simctl list devices available -j")
    if [ "${SIM_NO_GOLDEN}" = "1" ]; then
      echo '{"devices":{}}'
    else
      echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    fi
    ;;
  simctl\ boot\ *) ;;
  simctl\ bootstatus\ *) ;;
  simctl\ shutdown\ *) ;;
  simctl\ clone\ *) echo "CLONE-UUID-5678" ;;
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
  local session_id="${3:-test-session-golden}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}

# --- AC2.1: Golden boot on first clone request ---

@test "AC2.1: first clone request boots golden (boot + bootstatus + shutdown)" {
  run_guard "mcp__ios-simulator__tap" '{"x":100,"y":200}'
  grep -q "simctl boot GOLDEN-UUID-1234" "$XCRUN_LOG"
  grep -q "simctl bootstatus GOLDEN-UUID-1234" "$XCRUN_LOG"
  grep -q "simctl shutdown GOLDEN-UUID-1234" "$XCRUN_LOG"
}

# --- AC2.2: Marker created after golden init ---

@test "AC2.2: marker file is created after golden initialization" {
  run_guard "mcp__ios-simulator__tap" '{"x":100,"y":200}'
  [[ -f "$SIM_MARKER_DIR/atdd-kit-golden-initialized-iOS-18-0" ]]
}

# --- AC2.3: Second call skips golden boot ---

@test "AC2.3: second clone request skips golden boot (marker exists)" {
  touch "$SIM_MARKER_DIR/atdd-kit-golden-initialized-iOS-18-0"
  : > "$XCRUN_LOG"
  run_guard "mcp__ios-simulator__tap" '{"x":100,"y":200}'
  ! grep -q "simctl boot GOLDEN-UUID-1234" "$XCRUN_LOG"
}

# --- AC2.4: Error when golden image not found ---

@test "AC2.4: DENY with error when golden image not found" {
  export SIM_NO_GOLDEN=1
  result=$(run_guard "mcp__ios-simulator__tap" '{"x":100,"y":200}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  reason=$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecisionReason')
  [[ "$reason" == *"Golden image"* ]]
}

# --- AC2.5: Error message mentions Xcode Platforms ---

@test "AC2.5: error message mentions Xcode > Settings > Platforms" {
  export SIM_NO_GOLDEN=1
  result=$(run_guard "mcp__ios-simulator__tap" '{"x":100,"y":200}')
  reason=$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecisionReason')
  [[ "$reason" == *"Xcode"* && "$reason" == *"Platforms"* ]]
}

# --- AC2.6: Marker includes runtime version ---

@test "AC2.6: marker filename includes runtime version for re-init on Xcode update" {
  run_guard "mcp__ios-simulator__tap" '{"x":100,"y":200}'
  ls "$SIM_MARKER_DIR" | grep -q "iOS-18-0"
}

# --- AC2.7: guard script has ensure_golden function ---

@test "AC2.7: guard script defines ensure_golden function" {
  grep -q 'ensure_golden()' "$GUARD"
}
