> **Loaded by:** `session-start` (Step 3 route recommendation); referenced from `skills/autopilot/SKILL.md` (express precheck).

# Route Eligibility — Express vs Autopilot

Single source of truth for the express/autopilot route determination used in:
- `session-start` Step 3 (Recommended Tasks table 「推奨経路」column)
- `autopilot` express precheck (pre-flight advisory before Gate ①)

## Express-Eligible Signals

An Issue is express-eligible when it matches **one of the following** AND involves no behavior change:

- docs / README edits only
- typo fix only
- comment-only change
- `.gitignore` addition only
- version bump only (CHANGELOG entry included, no logic change)
- other purely documentary change that touches no functional logic

## Autopilot Signals

Use autopilot when **any of the following** apply:

- code change / behavior change / new feature (新機能 / 挙動変更)
- CI / hooks / scripts change
- dependency addition or update (依存パッケージ追加・更新)
- security-related change (セキュリティ関連)
- Issue carries the `type:development` label

## Hybrid Determination (label + keyword + LLM)

Evaluate in order:

1. **Labels** — `type:development` → autopilot (decisive).
2. **Keywords** — scan Issue title and body for express or autopilot signal terms (キーワード).
3. **LLM judgment** — when labels and keywords do not produce a clear signal, apply judgment to title + body.

## Ambiguous Fallback

When in doubt (ambiguous / 曖昧 / unclear / 不明): default to **autopilot** (full flow).
Express eligibility requires a clear positive signal; absence of a signal is not eligibility.

## Invariant — Recommendation Only, No Auto-Routing

This determination is **recommendation only** (推奨のみ). Auto-route (自動実行) is never performed.
The user retains final choice of route and may always override the recommendation.
