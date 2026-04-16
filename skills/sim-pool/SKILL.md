---
name: sim-pool
description: "iOS simulator exclusive access management. Auto-triggers via PreToolUse hook before XcodeBuildMCP / ios-simulator tool calls. Prevents simulator conflicts between sessions."
---

# Simulator Pool Management

Prevents simulator conflicts when multiple Claude Code sessions run in parallel on an iOS project.

## How It Works

- `.claude/hooks/sim-pool-guard.sh` runs as PreToolUse hook, capturing all XcodeBuildMCP / ios-simulator tool calls (`mcp__XcodeBuildMCP__.*`, `mcp__ios-simulator__.*`)
- Allowlist-based fail-closed: tools not explicitly listed are DENIED
- Each session gets an ephemeral simulator clone via `xcrun simctl clone` from a golden image (APFS CoW)
- For `ios-simulator` tools: clone UDID auto-injected via `updatedInput`
- For `XcodeBuildMCP` build/test/run: first call DENIED with instructions to run `session_set_defaults` pointing at clone

## Guard Behavior

| Tool Category | Behavior |
|---------------|----------|
| Read-only tools (`list_schemes`, `discover_projects`, etc.) | ALLOW immediately |
| Clone-required tools (`build`, `tap`, `take_screenshot`, etc.) | Ensure clone exists, then ALLOW with UDID injection |
| `session_set_defaults` / `session_use_defaults_profile` with `persist: true` | DENY (prevents cross-session pollution) |
| Unknown tools (not in any allowlist) | DENY with explanation (fail-closed) |

## Golden Image Device Set Isolation

By default, golden image is in the default Device Set (risks accidental use by Xcode, Fastlane, `simctl`).

When `SIM_GOLDEN_SET` is configured:
1. Golden operations use `xcrun simctl --set "$SIM_GOLDEN_SET"` — invisible to default `simctl list`
2. Clones via cross-set clone land in default Device Set for MCP compatibility
3. Unset/empty: falls back to default Device Set

## Ephemeral Clone Lifecycle

1. **Golden lazy init**: First request boots `SIM_GOLDEN_NAME`, waits for boot, shuts down, creates marker
2. **Clone creation**: `xcrun simctl clone` creates `atdd-kit-YYYYMMDDTHHMMSS-SESSION8`. With `SIM_GOLDEN_SET`: cross-set clone to default Device Set
3. **Session lock**: UDID and name stored in `$SESSION_DIR/$session_id`
4. **Orphan cleanup**: Stale clones (past TTL) auto-deleted before new clone creation

## Setup

Auto-configured on first iOS session or via `/atdd-kit:setup-ios`. See `${CLAUDE_PLUGIN_ROOT}/addons/ios/addon.yml`.

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

- **Clone not created**: verify golden image exists (`xcrun simctl list devices available` or with `--set "$SIM_GOLDEN_SET"`)
- **Stale clones**: auto-cleaned on each new clone; manual: `xcrun simctl delete <udid>`
- **Tool DENIED**: check `READONLY_TOOLS`/`CLONE_REQUIRED_TOOLS` in `sim-pool-guard.sh`
- **Golden in default list**: set `SIM_GOLDEN_SET` to a non-empty path
