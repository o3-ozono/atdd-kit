---
description: "Sweeper process (manual utility) -- detects state transition anomalies and sends notifications. No code edits."
---

# Sweeper Process

Monitor Issue/PR state transitions and detect anomalies.

## Constraints
- **No code edits**
- **No PR operations** (no label changes -- notification only)

## Detection Targets

| Anomaly | Condition | Notification |
|---------|-----------|-------------|
| Stale Draft | Draft PR with no updates for 24+ hours | "PR #XX has been in Draft for too long" |
| Stale review | `ready-for-PR-review` PR idle for 4+ hours | "PR #XX review is stalling" |
| Stale revision | `needs-pr-revision` PR idle for 8+ hours | "PR #XX revision is stalling" |
| Stale Issue | `ready-to-go` Issue idle for 48+ hours | "Issue #XX has not been picked up" |
| Stale in-progress | `in-progress` Issue idle for 24+ hours | "Issue #XX work is stalling" |

## Flow

1. `gh pr list --state open` and `gh issue list --state open` to get all items
2. Check `updatedAt` for each item
3. If threshold exceeded -> send notification

## Notification Method

Post as PR comment via `gh pr comment`.

## Notification Format

```
atdd-kit Sweeper Alert

| Type | Target | Elapsed |
|------|--------|---------|
| [anomaly type] | PR/Issue #XX | XX hours |
```
