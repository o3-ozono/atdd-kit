#!/usr/bin/env bats

# AC4: Backward compatibility — SIM_GOLDEN_SET unset falls back to default Device Set behavior.

setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  export SIM_CLONE_PREFIX="atdd-kit-"
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"
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
  simctl\ --set\ *\ list\ devices\ available\ -j)
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-SET","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    ;;
  simctl\ clone\ *) echo "CLONE-UUID-5678" ;;
  simctl\ --set\ *clone\ *) echo "CLONE-UUID-SET" ;;
  simctl\ boot\ *|simctl\ shutdown\ *|simctl\ bootstatus\ *) ;;
  "simctl list devices -j") echo '{"devices":{}}' ;;
  simctl\ --set\ *list\ devices\ -j) echo '{"devices":{}}' ;;
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
  local session_id="${3:-test-session-fallback}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}

# --- AC4.1: SIM_GOLDEN_SET unset uses default simctl (no --set) ---

@test "AC4.1: SIM_GOLDEN_SET unset — simctl commands have no --set flag" {
  unset SIM_GOLDEN_SET
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  # No --set should appear in any xcrun call
  ! grep -q "\-\-set" "$XCRUN_LOG"
}

# --- AC4.2: SIM_GOLDEN_SET set — simctl commands use --set ---

@test "AC4.2: SIM_GOLDEN_SET set — find_golden uses --set" {
  export SIM_GOLDEN_SET="${BATS_TMPDIR}/golden"
  mkdir -p "$SIM_GOLDEN_SET"
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  grep -q "\-\-set.*golden" "$XCRUN_LOG"
}

# --- AC4.3: SIM_GOLDEN_SET empty string treated as unset ---

@test "AC4.3: SIM_GOLDEN_SET empty string — falls back to default" {
  export SIM_GOLDEN_SET=""
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  ! grep -q "\-\-set" "$XCRUN_LOG"
}

# --- AC4.4: Guard defines simctl_golden function ---

@test "AC4.4: guard script defines simctl_golden helper function" {
  grep -q 'simctl_golden()' "$GUARD"
}

# --- AC4.5: SIM_GOLDEN_SET and SIM_DEFAULT_SET environment variables documented ---

@test "AC4.5: guard script references SIM_GOLDEN_SET environment variable" {
  grep -q 'SIM_GOLDEN_SET' "$GUARD"
}

@test "AC4.6: guard script references SIM_DEFAULT_SET environment variable" {
  grep -q 'SIM_DEFAULT_SET' "$GUARD"
}

# --- AC2: Golden search from separate Device Set ---

@test "AC2.1: SIM_GOLDEN_SET set — golden UDID comes from --set Device Set" {
  export SIM_GOLDEN_SET="${BATS_TMPDIR}/golden"
  mkdir -p "$SIM_GOLDEN_SET"
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"
  result=$(run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}')
  # The clone should use the golden from the --set Device Set (GOLDEN-UUID-SET)
  udid=$(echo "$result" | jq -r '.hookSpecificOutput.updatedInput.udid')
  [[ "$udid" == "CLONE-UUID-SET" ]]
}

@test "AC2.2: SIM_GOLDEN_SET set — list devices uses --set flag" {
  export SIM_GOLDEN_SET="${BATS_TMPDIR}/golden"
  mkdir -p "$SIM_GOLDEN_SET"
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  # The list devices call should include --set
  grep -q "simctl --set.*golden.*list devices available" "$XCRUN_LOG"
}

@test "AC2.3: SIM_GOLDEN_SET unset — golden UDID comes from default Device Set" {
  unset SIM_GOLDEN_SET
  result=$(run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}')
  udid=$(echo "$result" | jq -r '.hookSpecificOutput.updatedInput.udid')
  [[ "$udid" == "CLONE-UUID-5678" ]]
}

# --- AC1: Golden auto-creation in separate Device Set ---

@test "AC1.1: SIM_GOLDEN_SET — mkdir -p creates Device Set directory" {
  local golden_dir="${BATS_TMPDIR}/ac1-golden-$$"
  export SIM_GOLDEN_SET="$golden_dir"
  # Remove marker to trigger ensure_golden init path
  rm -f "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  [[ -d "$golden_dir" ]]
  rm -rf "$golden_dir"
}

@test "AC1.2: SIM_GOLDEN_SET — golden boot/shutdown use --set" {
  local golden_dir="${BATS_TMPDIR}/ac1-golden-boot-$$"
  export SIM_GOLDEN_SET="$golden_dir"
  mkdir -p "$golden_dir"
  # Remove marker to trigger golden init
  rm -f "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  grep -q "simctl --set.*ac1-golden-boot.*boot GOLDEN-UUID-SET" "$XCRUN_LOG"
  grep -q "simctl --set.*ac1-golden-boot.*shutdown GOLDEN-UUID-SET" "$XCRUN_LOG"
  rm -rf "$golden_dir"
}

@test "AC1.3: SIM_GOLDEN_SET — golden not visible in default simctl list" {
  # When GOLDEN_SET is configured, find_golden uses --set, so default
  # "simctl list devices available -j" (without --set) is never called for golden search
  export SIM_GOLDEN_SET="${BATS_TMPDIR}/ac1-invisible-$$"
  mkdir -p "$SIM_GOLDEN_SET"
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}'
  # Default "simctl list devices available -j" should NOT be called
  ! grep -q "^simctl list devices available -j$" "$XCRUN_LOG"
  rm -rf "$SIM_GOLDEN_SET"
}

# --- AC3: Cross-set clone behavior ---

@test "AC3.1: SIM_GOLDEN_SET — clone uses --set with destination argument" {
  export SIM_GOLDEN_SET="${BATS_TMPDIR}/ac3-golden-$$"
  export SIM_DEFAULT_SET="${BATS_TMPDIR}/ac3-default-$$"
  mkdir -p "$SIM_GOLDEN_SET" "$SIM_DEFAULT_SET"
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}' "test-session-ac3"
  # clone command should be: simctl --set <golden_set> clone <udid> <name> <default_set>
  grep -q "simctl --set.*ac3-golden.*clone GOLDEN-UUID-SET.*ac3-default" "$XCRUN_LOG"
  rm -rf "$SIM_GOLDEN_SET" "$SIM_DEFAULT_SET"
}

@test "AC3.2: SIM_GOLDEN_SET — clone boot uses default simctl (no --set)" {
  export SIM_GOLDEN_SET="${BATS_TMPDIR}/ac3-golden-boot-$$"
  mkdir -p "$SIM_GOLDEN_SET"
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}' "test-session-ac3b"
  # boot should be plain "simctl boot" without --set (clone is in default set)
  grep -q "^simctl boot CLONE-UUID-SET$" "$XCRUN_LOG"
  rm -rf "$SIM_GOLDEN_SET"
}

@test "AC3.3: SIM_GOLDEN_SET unset — clone uses plain simctl (no --set, no destination)" {
  unset SIM_GOLDEN_SET
  run_guard "mcp__ios-simulator__ui_tap" '{"x":100,"y":200}' "test-session-ac3c"
  # clone should be plain: simctl clone <udid> <name>
  local clone_line
  clone_line=$(grep "simctl clone" "$XCRUN_LOG")
  ! echo "$clone_line" | grep -q "\-\-set"
}
