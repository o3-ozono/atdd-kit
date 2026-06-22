> **Loaded by:** `session-start` (Step 3 route recommendation); referenced from `skills/autopilot/SKILL.md` (express precheck).

# Route Eligibility — Express vs Autopilot vs bugfix vs flaky

Single source of truth for the express / autopilot / bugfix route determination used in:
- `session-start` Step 3 (Recommended Tasks table 「推奨経路」column)
- `autopilot` express precheck (pre-flight advisory before Gate ①)
- `autopilot` bugfix-route precheck (which flow skills run — full feature route vs the `fixing-bugs` lightweight route)

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

## bugfix Route Signals

An Issue routes to the **bugfix** lightweight route (`fixing-bugs` / `/atdd-kit:bugfix`) — a code change that skips the full PRD/US/plan/AT spec and chains `bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying` — when it is a **defect fix** rather than new behavior:

- Issue carries the `type:bug` label (decisive signal).
- Keywords in title / body: bug / defect / 不具合 / 壊れた / broken / crash / regression / 直す / fix（既存挙動の修正）.
- Task content describes restoring intended-but-broken behavior, not adding a new feature.

The bugfix route is still a code/behavior change, so it stays under autopilot's full flow (not express); it differs only in **which** flow skills run (skips the three definition skills). Promotion back to the full feature route happens at `debugging` Step 5 when the root cause is **Type A (AC Gap)** — see `skills/fixing-bugs/SKILL.md`.

## flaky Route Signals

An Issue routes to the **flaky** lightweight route (`fixing-flaky-tests` / `/atdd-kit:flaky-fix`) — a code change that skips the full PRD/US/plan/AT spec and chains `bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying` — when it describes a **non-deterministically failing test** rather than a deterministic defect or new feature:

- Issue carries the `type:flaky` label (decisive signal).
- Keywords in title / body: `flaky` / `不安定` / `間欠的に失敗` / `intermittent` / probabilistically failing / sometimes fails.
- Task content describes determinizing a test that passes sometimes and fails other times (non-deterministic), not restoring always-broken behavior.

**flaky vs bugfix boundary:** flaky = test fails *non-deterministically* (outcome varies across runs without code changes); bugfix = test or behavior fails *deterministically* (reproducible every time). When in doubt, use the low-confidence fallback below.

The flaky route is still a code/behavior change, so it stays under autopilot's full flow (not express); it differs only in **which** flow skills run (skips the three definition skills) and in the convergence oracle (iterative N-consecutive-green rather than a single red→green). Promotion back to the full feature route happens at `debugging` Step 5 when the root cause is **Type A (AC Gap)** — see `skills/fixing-flaky-tests/SKILL.md`.

## Hybrid Determination (label + keyword + LLM)

Evaluate in order:

1. **Labels** — `type:development` → autopilot (decisive); `type:bug` → bugfix route (decisive); `type:flaky` → flaky route (decisive).
2. **Keywords** — scan Issue title and body for express / autopilot / bugfix / flaky signal terms (キーワード).
3. **LLM judgment** — when labels and keywords do not produce a clear signal, apply judgment to title + body.

### Low-confidence fallback (#305 one-tap)

When the bugfix-vs-flaky-vs-full-route signal is **low confidence** (label absent, mixed keywords, ambiguous task content), do not silently pick a route: present a **User confirmation** consistent with the #305 one-tap approval UI (AskUserQuestion, `(Recommended)` route first), and let the User choose. Absence of a clear bugfix or flaky signal is not eligibility for those routes — default to the full feature route.

## Ambiguous Fallback

When in doubt (ambiguous / 曖昧 / unclear / 不明): default to **autopilot** (full flow).
Express eligibility requires a clear positive signal; absence of a signal is not eligibility.

## Invariant — Recommendation Only, No Auto-Routing

This determination is **recommendation only** (推奨のみ). Auto-route (自動実行) is never performed.
The user retains final choice of route and may always override the recommendation.
