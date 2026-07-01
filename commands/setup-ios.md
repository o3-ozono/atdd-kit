---
description: "Manually set up the iOS addon for this project."
---

# setup-ios — iOS Addon Setup

Reads `addons/ios/addon.yml` and applies iOS-specific configuration to the project.

## Steps

### Step 1: Read Addon Manifest

Read `${CLAUDE_PLUGIN_ROOT}/addons/ios/addon.yml`.

### Step 2: Register MCP Servers

Add the following MCP servers to `.mcp.json`:

| Server | Command |
|--------|---------|
| XcodeBuildMCP | `npx -y xcodebuildmcp@latest mcp` |
| ios-simulator | `npx -y ios-simulator-mcp` |
| apple-docs | `npx -y @kimsungwhee/apple-docs-mcp@latest` |
| xcode | `xcrun mcpbridge` |

### Step 3: Deploy Scripts

Copy addon scripts to the project:

| Source (plugin) | Destination (project) |
|-----------------|----------------------|
| `addons/ios/scripts/sim-pool-guard.sh` | `.claude/hooks/sim-pool-guard.sh` |
| `addons/ios/scripts/lint-xcstrings.sh` | `scripts/lint-xcstrings.sh` |
| `scripts/impact_map.sh` | `scripts/impact_map.sh` |
| `addons/ios/config/impact_rules.yml` | `config/impact_rules.yml` |

**Re-run protection (existing customized config):** Before copying `config/impact_rules.yml`,
check whether the destination file **already exists**. If it does, this is a re-run of
`setup-ios` on a project that has already customized its rules — **do not silently
overwrite** it. Print an overwrite warning and **skip** (preserve) the existing file. This
matters more for iOS than Web: the shipped `impact_rules.yml` template's `path:` globs and
`skill-e2e:` XCTest/XCUITest target names are placeholders that are **required** to be
edited to match the project's actual Xcode layout — an unconditional overwrite on re-run
would silently discard that required, hand-tuned customization and put the project back to
the (non-functional, full-suite-fallback) template defaults.

### Step 4: Configure Hooks

Add PreToolUse hooks to `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "mcp__XcodeBuildMCP__.*", "command": ".claude/hooks/sim-pool-guard.sh", "timeout": 90 },
      { "matcher": "mcp__ios-simulator__.*", "command": ".claude/hooks/sim-pool-guard.sh", "timeout": 90 }
    ]
  }
}
```

### Step 5: Display Guidance

Print addon guidance from `addon.yml` (Golden Image Device Set isolation).

### Step 6: Summary

```
iOS addon setup complete:
- MCP servers: 4 registered
- Scripts: 4 deployed
- Hooks: 2 configured
```
