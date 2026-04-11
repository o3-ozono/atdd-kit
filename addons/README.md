# Addons

Platform-specific addon packages. Each addon is a self-contained directory with a declarative `addon.yml` manifest.

## Available Addons

| Addon | Directory | Auto-Detection |
|-------|-----------|----------------|
| iOS | `ios/` | `*.xcodeproj`, `*.xcworkspace`, `Package.swift` |

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

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Addon identifier (lowercase) |
| `display_name` | string | Human-readable name |
| `skills` | string[] | Skills this addon provides (must exist in `skills/`) |
| `mcp_servers` | object | MCP servers to register in `.mcp.json` |
| `hooks` | object | PreToolUse hooks to add to `.claude/settings.json` |
| `deploy` | array | Files to copy to user project (`src` → `dest`) |
| `ci_job` | string | Path to CI job fragment YAML |
| `detect` | object | Auto-detection patterns (file globs) |
| `guidance` | string | Post-setup guidance text |

## Adding a New Addon

1. Create `addons/<platform>/` with `addon.yml`
2. Add scripts, CI fragments, and tests
3. Register addon skills in `skills/` (framework requires `skills/*/SKILL.md` for discovery)
4. Update this README
