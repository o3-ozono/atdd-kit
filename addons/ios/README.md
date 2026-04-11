# iOS Addon

Platform addon for iOS development with Claude Code.

## What This Addon Provides

| Component | Description |
|-----------|-------------|
| **sim-pool** skill | Simulator pool management (ephemeral clones, golden image isolation) |
| **ui-test-debugging** skill | CI UI test failure diagnosis via Allure reports |
| **sim-pool-guard.sh** | PreToolUse hook for fail-closed simulator access control |
| **lint-xcstrings.sh** | Japanese translation coverage linter for .xcstrings files |
| **CI job fragment** | xcodebuild build + test job for GitHub Actions |

## Auto-Detection

This addon activates when the project contains any of:
- `*.xcodeproj`
- `*.xcworkspace`
- `Package.swift`

## Manual Setup

If auto-detection does not work (e.g., new project without Xcode files yet):

```
/atdd-kit:setup-ios
```

## MCP Servers

| Server | Purpose |
|--------|---------|
| XcodeBuildMCP | Xcode build/test automation |
| ios-simulator | iOS simulator control |
| apple-docs | Apple documentation access |
| xcode | Xcode MCP bridge |

## Files Deployed to User Projects

| Source | Destination | Purpose |
|--------|-------------|---------|
| `scripts/sim-pool-guard.sh` | `.claude/hooks/sim-pool-guard.sh` | PreToolUse hook |
| `scripts/lint-xcstrings.sh` | `scripts/lint-xcstrings.sh` | String linting |
