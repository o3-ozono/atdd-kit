---
name: sim-pool
description: "iOS simulator exclusive access management. Auto-triggers via PreToolUse hook before XcodeBuildMCP / ios-simulator tool calls. Prevents simulator conflicts between sessions."
---

# Simulator Pool Management

Prevents simulator conflicts when multiple Claude Code sessions run in parallel on an iOS project.

## How It Works

- `.claude/hooks/sim-pool-guard.sh` runs as a PreToolUse hook, capturing **all** XcodeBuildMCP / ios-simulator tool calls via catch-all matchers (`mcp__XcodeBuildMCP__.*`, `mcp__ios-simulator__.*`)
- The guard uses an **allowlist-based fail-closed** design: tools not explicitly listed are DENIED
- Each session gets an **ephemeral simulator clone** via `xcrun simctl clone` from a golden image (APFS CoW — fast and disk-efficient)
- For `ios-simulator` tools, the clone's UDID is auto-injected via `updatedInput`
- For `XcodeBuildMCP` build/test/run, the first call is DENIED with instructions to run `session_set_defaults` pointing at the clone

## Guard Behavior

| Tool Category | Behavior |
|---------------|----------|
| Read-only tools (`list_schemes`, `discover_projects`, etc.) | ALLOW immediately |
| Clone-required tools (`build`, `tap`, `take_screenshot`, etc.) | Ensure clone exists, then ALLOW with UDID injection |
| `session_set_defaults` / `session_use_defaults_profile` with `persist: true` | DENY (prevents cross-session pollution) |
| Unknown tools (not in any allowlist) | DENY with explanation (fail-closed) |

## Golden Image Device Set Isolation

By default, the golden image lives in the default Device Set alongside user simulators. This risks accidental use by Xcode, Fastlane, or manual `simctl` operations.

When `SIM_GOLDEN_SET` is configured, the guard isolates the golden image in a separate Device Set:

1. All golden operations (`find_golden`, `ensure_golden`) use `xcrun simctl --set "$SIM_GOLDEN_SET"`
2. The golden image is invisible to default `simctl list` and Xcode device lists
3. Clones are created via cross-set clone with a destination argument: the clone lands in the default Device Set for MCP tool compatibility
4. If `SIM_GOLDEN_SET` is unset or empty, the guard falls back to default Device Set behavior (backward compatible)

## Ephemeral Clone Lifecycle

1. **Golden image lazy init**: First request boots the golden simulator (`SIM_GOLDEN_NAME`), waits for boot completion, shuts down, and creates a runtime-versioned marker file
2. **Clone creation**: `xcrun simctl clone` creates a per-session clone named `atdd-kit-YYYYMMDDTHHMMSS-SESSION8`. When `SIM_GOLDEN_SET` is configured, uses cross-set clone to place the clone in the default Device Set
3. **Session lock**: Clone UDID and name stored in `$SESSION_DIR/$session_id`
4. **Orphan cleanup**: Before creating a new clone, stale clones (past TTL) are automatically deleted

## Setup

Auto-configured when iOS platform is detected at first session, or via `/atdd-kit:setup-ios`:
- `addons/ios/scripts/sim-pool-guard.sh` -> project's `.claude/hooks/sim-pool-guard.sh`
- PreToolUse hook definition added to `.claude/settings.json`

See `${CLAUDE_PLUGIN_ROOT}/addons/ios/addon.yml` for the full addon manifest.

## Environment Overrides (Testing)

| Variable | Default | Purpose |
|----------|---------|---------|
| `SIM_SESSION_DIR` | `/tmp/claude-sim-sessions` | Session lock directory |
| `SIM_MARKER_DIR` | `/tmp` | Golden init marker directory |
| `SIM_GOLDEN_NAME` | `iPhone 17 Pro` | Golden image name |
| `SIM_GOLDEN_SET` | (empty) | Device Set path for golden image isolation. Empty = default Device Set |
| `SIM_DEFAULT_SET` | `~/Library/Developer/CoreSimulator/Devices` | Device Set path for clones (cross-set clone destination) |
| `SIM_TTL_LOCAL` | `7200` | Local TTL in seconds (2h) |
| `SIM_TTL_CI` | `2400` | CI TTL in seconds (40min) |
| `SIM_CLONE_PREFIX` | `atdd-kit-` | Clone name prefix |

## Troubleshooting

- **Clone not created**: Check that the golden image exists — `xcrun simctl list devices available` should show `SIM_GOLDEN_NAME`. If `SIM_GOLDEN_SET` is configured, use `xcrun simctl --set "$SIM_GOLDEN_SET" list devices` instead
- **Stale clones accumulating**: Cleanup runs automatically on each clone creation; manual cleanup: `xcrun simctl delete <udid>`
- **Tool DENIED unexpectedly**: Check if the tool is in `READONLY_TOOLS` or `CLONE_REQUIRED_TOOLS` in `sim-pool-guard.sh`
- **Golden visible in default device list**: Ensure `SIM_GOLDEN_SET` is set to a non-empty path. The golden should only appear in `xcrun simctl --set "$SIM_GOLDEN_SET" list devices`
