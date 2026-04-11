#!/usr/bin/env bash
# addons/ios/scripts/sim-pool-guard.sh — Ephemeral Clone + Fail-Closed Guard
#
# PreToolUse hook: captures ALL XcodeBuildMCP / ios-simulator tool calls.
# Uses allowlist-based routing — unknown tools are DENIED (fail-closed).
# Manages ephemeral simulator clones per session via xcrun simctl clone.
#
# Environment overrides (for testing):
#   SIM_SESSION_DIR   — session lock directory (default: /tmp/claude-sim-sessions)
#   SIM_MARKER_DIR    — golden init marker directory (default: /tmp)
#   SIM_GOLDEN_NAME   — golden image name (default: iPhone 17 Pro)
#   SIM_GOLDEN_SET    — Device Set path for golden image isolation (default: empty = default Device Set)
#   SIM_DEFAULT_SET   — Device Set path for clones / default operations (default: ~/Library/Developer/CoreSimulator/Devices)
#   SIM_TTL_LOCAL     — TTL for local sessions in seconds (default: 7200)
#   SIM_TTL_CI        — TTL for CI sessions in seconds (default: 2400)
#   SIM_CLONE_PREFIX  — clone name prefix (default: atdd-kit-)

set -euo pipefail

# ── Constants ────────────────────────────────────────────
SESSION_DIR="${SIM_SESSION_DIR:-/tmp/claude-sim-sessions}"
MARKER_DIR="${SIM_MARKER_DIR:-/tmp}"
GOLDEN_NAME="${SIM_GOLDEN_NAME:-iPhone 17 Pro}"
GOLDEN_SET="${SIM_GOLDEN_SET:-}"
DEFAULT_SET="${SIM_DEFAULT_SET:-$HOME/Library/Developer/CoreSimulator/Devices}"
CLONE_PREFIX="${SIM_CLONE_PREFIX:-atdd-kit-}"
TTL_LOCAL="${SIM_TTL_LOCAL:-7200}"
TTL_CI="${SIM_TTL_CI:-2400}"
LOCK_WAIT_TIMEOUT=60

# ── Allowlist ────────────────────────────────────────────
# Read-only tools — always ALLOW without requiring a clone
READONLY_TOOLS=(
  "mcp__XcodeBuildMCP__list_schemes"
  "mcp__XcodeBuildMCP__list_targets"
  "mcp__XcodeBuildMCP__list_devices"
  "mcp__XcodeBuildMCP__list_device_types"
  "mcp__XcodeBuildMCP__list_runtimes"
  "mcp__XcodeBuildMCP__discover_projects"
  "mcp__XcodeBuildMCP__show_build_settings"
  "mcp__XcodeBuildMCP__get_build_logs"
  "mcp__XcodeBuildMCP__get_swift_packages"
  "mcp__XcodeBuildMCP__session_show_defaults"
  "mcp__XcodeBuildMCP__session_clear_defaults"
  "mcp__XcodeBuildMCP__clean_build"
  "mcp__ios-simulator__get_booted_simulators"
  "mcp__ios-simulator__stop_recording"
)

# Clone-required tools — ALLOW only with an active clone
CLONE_REQUIRED_TOOLS=(
  "mcp__XcodeBuildMCP__build"
  "mcp__XcodeBuildMCP__build_sim"
  "mcp__XcodeBuildMCP__build_run_sim"
  "mcp__XcodeBuildMCP__test"
  "mcp__XcodeBuildMCP__test_sim"
  "mcp__XcodeBuildMCP__run"
  "mcp__XcodeBuildMCP__session_set_defaults"
  "mcp__XcodeBuildMCP__session_use_defaults_profile"
  "mcp__ios-simulator__launch_app"
  "mcp__ios-simulator__terminate_app"
  "mcp__ios-simulator__tap"
  "mcp__ios-simulator__swipe"
  "mcp__ios-simulator__long_press"
  "mcp__ios-simulator__type_text"
  "mcp__ios-simulator__press_button"
  "mcp__ios-simulator__open_url"
  "mcp__ios-simulator__take_screenshot"
  "mcp__ios-simulator__list_apps"
  "mcp__ios-simulator__get_ui_hierarchy"
  "mcp__ios-simulator__start_recording"
  "mcp__ios-simulator__add_media"
  "mcp__ios-simulator__set_location"
  "mcp__ios-simulator__clear_keychain"
  "mcp__ios-simulator__get_app_container"
  "mcp__ios-simulator__push_notification"
  "mcp__ios-simulator__set_permission"
  "mcp__ios-simulator__uninstall_app"
  "mcp__ios-simulator__boot_simulator"
  "mcp__ios-simulator__shutdown_simulator"
  "mcp__ios-simulator__erase_simulator"
)

# Persist-check tools — check for persist: true before allowing
PERSIST_CHECK_TOOLS=(
  "mcp__XcodeBuildMCP__session_set_defaults"
  "mcp__XcodeBuildMCP__session_use_defaults_profile"
)

# ── Helpers ──────────────────────────────────────────────

simctl_golden() {
  if [ -n "$GOLDEN_SET" ]; then
    xcrun simctl --set "$GOLDEN_SET" "$@"
  else
    xcrun simctl "$@"
  fi
}

in_array() {
  local target="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$target" ]] && return 0
  done
  return 1
}

emit_allow() {
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
JSON
}

emit_deny() {
  local reason="$1"
  jq -n --arg reason "$reason" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason}}'
}

emit_deny_with_context() {
  local reason="$1"
  local context="$2"
  jq -n --arg reason "$reason" --arg context "$context" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason,"additionalContext":$context}}'
}

emit_allow_with_input() {
  local updated_input="$1"
  jq -n --argjson input "$updated_input" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":$input}}'
}

# ── Golden Image ─────────────────────────────────────────

find_golden() {
  local golden_udid
  golden_udid=$(simctl_golden list devices available -j 2>/dev/null \
    | jq -r --arg name "$GOLDEN_NAME" \
      '.devices | to_entries[] | .value[] | select(.name == $name and .isAvailable == true) | .udid' \
    | head -1)
  echo "$golden_udid"
}

get_golden_runtime() {
  simctl_golden list devices available -j 2>/dev/null \
    | jq -r --arg name "$GOLDEN_NAME" \
      '.devices | to_entries[] | .value[] | select(.name == $name and .isAvailable == true) | .runtime' \
    | head -1 \
    | sed 's/.*\.//'
}

ensure_golden() {
  # Sets GOLDEN_UDID as side effect. Returns 1 if golden not found.
  # Create golden Device Set directory if specified and missing
  if [ -n "$GOLDEN_SET" ]; then
    mkdir -p "$GOLDEN_SET"
  fi

  GOLDEN_UDID=$(find_golden)
  if [ -z "$GOLDEN_UDID" ]; then
    return 1
  fi

  local runtime_version
  runtime_version=$(get_golden_runtime)
  local marker="${MARKER_DIR}/atdd-kit-golden-initialized-${runtime_version}"

  if [ -f "$marker" ]; then
    return 0
  fi

  # First-time boot to initialize golden image
  simctl_golden boot "$GOLDEN_UDID" 2>/dev/null || true
  simctl_golden bootstatus "$GOLDEN_UDID" -b 2>/dev/null || true
  simctl_golden shutdown "$GOLDEN_UDID" 2>/dev/null || true

  touch "$marker"
  return 0
}

# ── Clone Management ─────────────────────────────────────

ensure_clone() {
  local session_id="$1"
  local lock_file="${SESSION_DIR}/${session_id}"

  mkdir -p "$SESSION_DIR"

  # Already have a clone for this session
  if [ -f "$lock_file" ]; then
    return 0
  fi

  # Atomic lock for clone creation
  local creating_dir="${SESSION_DIR}/${session_id}.creating"
  local waited=0
  if ! mkdir "$creating_dir" 2>/dev/null; then
    # Another invocation is creating the clone — wait
    while [ -d "$creating_dir" ] && [ $waited -lt $LOCK_WAIT_TIMEOUT ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if [ -d "$creating_dir" ]; then
      rmdir "$creating_dir" 2>/dev/null || true
    fi
    if [ -f "$lock_file" ]; then
      return 0
    fi
    mkdir "$creating_dir" 2>/dev/null || true
  fi

  # Clean up stale clones before creating new one
  cleanup_stale_clones

  # Ensure golden image is initialized
  if ! ensure_golden; then
    rmdir "$creating_dir" 2>/dev/null || true
    emit_deny "sim-pool: Golden image '${GOLDEN_NAME}' not found. Install iOS runtime via Xcode > Settings > Platforms."
    exit 0
  fi

  # Create clone
  local timestamp
  timestamp=$(date +%Y%m%dT%H%M%S)
  local short_session="${session_id:0:8}"
  local clone_name="${CLONE_PREFIX}${timestamp}-${short_session}"

  local clone_udid
  if [ -n "$GOLDEN_SET" ]; then
    clone_udid=$(xcrun simctl --set "$GOLDEN_SET" clone "$GOLDEN_UDID" "$clone_name" "$DEFAULT_SET" 2>/dev/null) || {
      rmdir "$creating_dir" 2>/dev/null || true
      emit_deny "sim-pool: Failed to create simulator clone."
      exit 0
    }
  else
    clone_udid=$(xcrun simctl clone "$GOLDEN_UDID" "$clone_name" 2>/dev/null) || {
      rmdir "$creating_dir" 2>/dev/null || true
      emit_deny "sim-pool: Failed to create simulator clone."
      exit 0
    }
  fi

  # Boot the clone (always in default Device Set)
  xcrun simctl boot "$clone_udid" 2>/dev/null || true

  # Write lock file: UDID|NAME
  echo "${clone_udid}|${clone_name}" > "$lock_file"

  rmdir "$creating_dir" 2>/dev/null || true
  return 0
}

get_clone_info() {
  local session_id="$1"
  local lock_file="${SESSION_DIR}/${session_id}"
  if [ -f "$lock_file" ]; then
    cat "$lock_file"
  fi
}

# ── Orphan Cleanup ───────────────────────────────────────

cleanup_stale_clones() {
  local ttl=$TTL_LOCAL
  [ -n "${GITHUB_ACTIONS:-}" ] && ttl=$TTL_CI
  local now
  now=$(date +%s)

  xcrun simctl list devices -j 2>/dev/null \
    | jq -r --arg prefix "$CLONE_PREFIX" \
      '.devices | to_entries[] | .value[] | select(.name | startswith($prefix)) | "\(.name)|\(.udid)"' \
    | while IFS='|' read -r name udid; do
        local ts_str="${name#${CLONE_PREFIX}}"
        ts_str="${ts_str%%-*}"  # YYYYMMDDTHHMMSS

        local clone_epoch
        if date -j +%s 2>/dev/null >&2; then
          clone_epoch=$(date -j -f "%Y%m%dT%H%M%S" "$ts_str" +%s 2>/dev/null || echo 0)
        else
          local formatted="${ts_str:0:4}-${ts_str:4:2}-${ts_str:6:2}T${ts_str:9:2}:${ts_str:11:2}:${ts_str:13:2}"
          clone_epoch=$(date -d "$formatted" +%s 2>/dev/null || echo 0)
        fi

        local age=$(( now - clone_epoch ))
        if [ "$age" -gt "$ttl" ]; then
          xcrun simctl shutdown "$udid" 2>/dev/null || true
          xcrun simctl delete "$udid" 2>/dev/null || true
        fi
      done
}

# ── Handlers ─────────────────────────────────────────────

handle_persist_check() {
  local tool_input="$1"
  local persist_val
  persist_val=$(echo "$tool_input" | jq -r '.persist // empty')
  if [ "$persist_val" = "true" ]; then
    emit_deny "sim-pool: persist: true is blocked to prevent cross-session pollution. Use persist: false or omit persist."
    exit 0
  fi
}

handle_xcodebuildmcp() {
  local session_id="$1"
  local tool_name="$2"
  local tool_input="$3"

  ensure_clone "$session_id" || {
    emit_deny "sim-pool: Failed to create simulator clone."
    exit 0
  }

  local clone_info
  clone_info=$(get_clone_info "$session_id")
  local clone_udid="${clone_info%%|*}"
  local clone_name="${clone_info#*|}"

  local setup_flag="${SESSION_DIR}/${session_id}.setup"

  if [ "$tool_name" = "mcp__XcodeBuildMCP__session_set_defaults" ]; then
    touch "$setup_flag"
    emit_allow
    exit 0
  fi

  if [ "$tool_name" = "mcp__XcodeBuildMCP__session_use_defaults_profile" ]; then
    rm -f "$setup_flag"
    emit_allow
    exit 0
  fi

  # For build/test/run: require session_set_defaults first
  if [ ! -f "$setup_flag" ]; then
    touch "$setup_flag"
    emit_deny_with_context \
      "sim-pool: Simulator clone ready. Run session_set_defaults first." \
      "[sim-pool] Clone ready: ${clone_name} (${clone_udid})\n\nBefore proceeding, run:\n  mcp__XcodeBuildMCP__session_set_defaults({ simulatorName: \"${clone_name}\", persist: false })\n\nIMPORTANT: Never use persist: true."
    exit 0
  fi

  emit_allow
}

handle_ios_simulator() {
  local session_id="$1"
  local tool_input="$2"

  ensure_clone "$session_id" || {
    emit_deny "sim-pool: Failed to create simulator clone."
    exit 0
  }

  local clone_info
  clone_info=$(get_clone_info "$session_id")
  local clone_udid="${clone_info%%|*}"

  local updated_input
  updated_input=$(echo "$tool_input" | jq --arg udid "$clone_udid" '. + {udid: $udid}')

  emit_allow_with_input "$updated_input"
}

# ── Main ─────────────────────────────────────────────────

main() {
  local input
  input=$(cat)

  local tool_name
  tool_name=$(echo "$input" | jq -r '.tool_name // ""')
  local tool_input
  tool_input=$(echo "$input" | jq -c '.tool_input // {}')
  local session_id
  session_id=$(echo "$input" | jq -r '.session_id // ""')

  # No session_id — passthrough
  if [ -z "$session_id" ]; then
    emit_allow
    exit 0
  fi

  # 1. READONLY_TOOLS — immediate ALLOW
  if in_array "$tool_name" "${READONLY_TOOLS[@]}"; then
    emit_allow
    exit 0
  fi

  # 2. Persist check for relevant tools
  if in_array "$tool_name" "${PERSIST_CHECK_TOOLS[@]}"; then
    handle_persist_check "$tool_input"
  fi

  # 3. CLONE_REQUIRED_TOOLS — ensure clone, then handle
  if in_array "$tool_name" "${CLONE_REQUIRED_TOOLS[@]}"; then
    case "$tool_name" in
      mcp__XcodeBuildMCP__*)
        handle_xcodebuildmcp "$session_id" "$tool_name" "$tool_input"
        ;;
      mcp__ios-simulator__*)
        handle_ios_simulator "$session_id" "$tool_input"
        ;;
    esac
    exit 0
  fi

  # 4. Unknown tool — DENY (fail-closed)
  emit_deny "sim-pool: Unknown tool '${tool_name}' is not in the allowlist. DENIED for safety. If this tool is safe, add it to READONLY_TOOLS or CLONE_REQUIRED_TOOLS in sim-pool-guard.sh."
  exit 0
}

main
