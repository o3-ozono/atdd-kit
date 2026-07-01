# Addons

Platform-specific addon packages. Each addon is a self-contained directory with a declarative `addon.yml` manifest.

## Available Addons

| Addon | Directory | Auto-Detection |
|-------|-----------|----------------|
| Web | `web/` | `package.json`, `next.config.*`, `vite.config.*`, `nuxt.config.*`, `svelte.config.*` |
| iOS | `ios/` | `*.xcodeproj`, `*.xcworkspace`, `Package.swift` |
| Discord notifications | `discord/` | **opt-in** (no auto-detect; session-start asks `[y/N]` default N, or `/atdd-kit:setup-discord`) |

## Addon Structure

```
addons/<platform>/
├── addon.yml          # Declarative manifest (MCP servers, hooks, deploy files, CI)
├── scripts/           # Platform-specific scripts
├── ci/                # CI job fragment (composed with templates/ci/base.yml)
├── tests/             # BATS tests for this addon
└── README.md          # Addon documentation
```

## addon.yml Schema

| Field | Type | Required / Optional | Description |
|-------|------|----------------------|-------------|
| `name` | string | Required | Addon identifier (lowercase) |
| `display_name` | string | Required | Human-readable name |
| `skills` | string[] | Optional | Skills this addon provides (must exist in `skills/`) |
| `mcp_servers` | object | Optional | MCP servers to register in `.mcp.json` (user-project declaration — see `DEVELOPMENT.md` Zero Dependencies carve-out) |
| `hooks` | object | Optional | PreToolUse hooks to add to `.claude/settings.json` |
| `deploy` | array | Required | Files to copy to user project (`src` → `dest`) |
| `deploy[].if_not_exists` | boolean | Optional — **reserved** | Per-entry: when `true`, skip deploying `dest` if it already exists (protects a user's customized file on setup re-run). Not yet implemented — behavior deferred to a future Issue (#347); currently informational only. |
| `deploy[].merge_strategy` | string | Optional — **reserved** | Per-entry: how to reconcile an updated template with existing customization (e.g. `overwrite`). Not yet implemented — behavior deferred to a future Issue (#347); currently informational only. |
| `ci_job` | string | Optional | Path to CI job fragment YAML |
| `detect` | object | Optional | Auto-detection patterns (file globs) |
| `guidance` | string | Optional | Post-setup guidance text |

## Adding a New Addon

1. Create `addons/<platform>/` with `addon.yml`
2. Add scripts, CI fragments, and tests
3. Register addon skills in `skills/` (framework requires `skills/*/SKILL.md` for discovery)
4. Update this README
