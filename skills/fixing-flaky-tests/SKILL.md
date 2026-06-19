---
name: fixing-flaky-tests
description: "Use when a test is flaky / 不安定 / intermittent / probabilistically failing, or via explicit /atdd-kit:flaky-fix <issue>."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# fixing-flaky-tests Skill — Lightweight flaky-test-fix Route (sibling of fixing-bugs)

A thin **orchestration** skill for the flaky-test category. It does **not** introduce a new methodology, step, or diagnostic logic — it **only reuses** existing skills, bundling them into a shorter chain tuned for non-deterministic test failures. The probabilistic reproduction methodology, root-cause diagnosis, ATDD (determinization), review, and merge all live in the existing skills; this skill only routes between them.

The full feature route formalizes every change into Connextra User Stories + Plan + AT spec. For a flaky test, that formalization interrupts the empirical debugging cycle. So the flaky route **skips** the three definition skills and chains the rest.

## Skill Chain (orchestrator-driven)

| # | Skill | Role on this route |
|---|-------|--------------------|
| 1 | `bug` | intake / Issue 化 / triage |
| 2 | `debugging` | 非決定性の原因分類（`debugging` の既存 Type を flaky 軸で運用: Type C 配下の運用サブ軸） |
| 3 | `running-atdd-cycle` | 決定化する最小修正 + 反復ベース回帰（反復 failing アンカー 赤→N 回連続緑） |
| 4 | `reviewing-deliverables` | 成果物レビュー |
| 5 | `merging-and-deploying` | マージ + post-deploy 回帰（User gate 必須） |

**Skipped (full feature route only):** `defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests`. Reason: these formalize a change into a PRD → Connextra User Stories → Plan + AT spec; for a non-deterministic test failure that formalization stops you from going straight at the flaky test's root cause. The flaky route reuses the remaining 5 skills as-is and **defines no new methodology** — it only binds the existing skills together (zero duplication).

## Forward-chain override (orchestrator-driven invocation)

The existing `bug` skill hard-codes a forward "Next Step" that invokes `defining-requirements`. That directly conflicts with the flaky route, which skips `defining-requirements`. The fix does **not** edit `bug` (or any chained skill — Non-Goal). Instead the override lives here:

- On the flaky route, **`fixing-flaky-tests` is the orchestrator** and drives each skill's Skill-tool invocation explicitly (**orchestrator-driven invocation**).
- Each chained skill's own **"Next Step"** is, under this route, **advisory only** (a hint about the next stage); the `fixing-flaky-tests` chain definition above **overrides** that self-routing forward chain.
- Concretely: after `bug` completes, do **not** follow `bug`'s Next Step to `defining-requirements` — instead, per this chain, invoke `debugging` next.

This intercepts `bug`'s forward chain **without editing `bug`**. `bug` / `debugging` / `running-atdd-cycle` / `reviewing-deliverables` / `merging-and-deploying` SKILL.md files are left unedited (Non-Goal: no essential rewrite of the reused skills).

## Probabilistic reproduction wiring (two layers)

### 2a. Probabilistic reproduction confirmation (empirical, iterative tool-driven)

Before encoding anything, **reproduce the flaky behavior with real tools**, platform-aware. Read `.claude/config.yml`'s `platform` and branch:

| platform | tool | means |
|----------|------|-------|
| other | CLI / bats loop execution | Run the test in a loop (repeated launches); seed injection / execution-order shuffle as needed |
| web | `playwright-cli` iterative runs (**external skill** — environment/global, not atdd-kit-owned) | Repeat runs; vary seed / execution order for ordering-sensitive flakiness |
| iOS | Xcode / simulator MCP iterative runs (**external tool/MCP**) + `sim-pool` (atdd-kit-owned) | Repeat runs; vary parallelism / simulator state |

Run **N iterations** (N is configurable with a minimum lower bound; do not pin a literal N) — vary seed, execution order, and/or parallelism level depending on the suspected failure category. **Record the failure rate** (red count / total runs). Observing **at least one red in N iterations** is the firsthand reproduction evidence. **Single-run execution is not accepted as reproduction confirmation** — a single green means nothing for a flaky test.

`playwright-cli` / Xcode-simulator MCP are referenced as **external skills / external MCP only** — the flaky route does **not** create or register them as atdd-kit-local skills, does not add them to `skills/README.md`, and generates no BATS structural test for them. Only `sim-pool` is an atdd-kit-owned skill.

### 2b. Encode into a repeatedly-failing anchor

Encode the confirmed non-determinism as an **executable anchor that turns red with non-zero probability in repeated execution**. This anchor becomes the cause-agreement gate's approved deliverable and the convergence oracle's anchor:

- **Before the fix**: the anchor is observed red at least once in N iterations (the failure rate > 0%).
- **After the fix**: the anchor must turn **green for N consecutive iterations** (determinization confirmed). Single-run green is not accepted as convergence — **N consecutive greens confirm determinization**.

The convergence oracle is therefore: **N consecutive greens (determinization confirmed) ＋ 既存テスト非破壊 (no regressions in existing tests)**.

## Non-determinism root-cause classification (flaky axis of `debugging` Types)

`debugging`'s existing Type classification is used to categorize the non-determinism cause — no new Type axis is added to `debugging`. The flaky axis operates as a **sub-axis under Type C (Logic Error family)** for the following non-determinism categories:

| Non-determinism category | Description |
|--------------------------|-------------|
| Timing-dependent | Race conditions, async delays, clock-sensitive behavior |
| Order-dependent | Test execution order sensitivity, shared mutable state across tests |
| Shared-state | Global or process-level state leaked between test runs |
| External-dependency | Network, filesystem, third-party API flakiness |
| Resource-leak | File descriptors, ports, memory not released between runs |

`debugging` SKILL.md is **not edited** — the flaky-axis operational guidance lives here in the orchestrator (zero duplication). Type A (AC Gap = 仕様/設計判断が必要) upgrades to the full feature route (see below).

## cause-agreement gate (the flaky route's middle User gate — AL-1 preserved)

The flaky route writes no US/Plan/AT spec, so the standard **design-approval gate** has no user-stories/plan/acceptance-tests deliverable to anchor. Rather than remove a gate (forbidden by AL-1), the middle gate is **specialized to a cause-agreement gate**: its approval target is **`debugging` Step 5's non-determinism root-cause classification (Type, flaky sub-axis, evidence 付き) ＋ the repeatedly-failing anchor ＋ failure rate (修正前 X% → 修正後 0%)**.

**ATDD (the determinization fix) never starts before the cause-agreement gate.** The approval target is non-empty (classification + iterative failing anchor + failure rate), so AL-1's "ATDD never starts before that gate" holds. `debugging` already ends Step 5 with a `Proceed to fix?` human confirmation (reused as-is). On the flaky route that confirmation **is** the cause-agreement gate's role.

The gate count stays three (discover requirements approval → cause-agreement → merge) — this is a specialization, not a removal or added gate. Full spec in `docs/methodology/autopilot-iron-law.md` (AL-1 flaky specialization) and `docs/methodology/autopilot-design-gate.md` (presentation contract); both docs agree the flaky middle gate is the **cause-agreement** gate with approval target = non-determinism classification ＋ failure rate.

## quarantine (temporary isolation) judgment point

When immediate determinization is not feasible (complex root cause, insufficient time, out-of-scope dependency):

1. **Isolate** the flaky test with a platform-aware temporary isolation marker (external runner features only — no atdd-kit-local isolation implementation):
   - other (bats): `skip` directive or a test tag
   - web: Playwright `test.fixme()` or `test.skip()`
   - iOS: `XCTSkip`
2. **Track** — isolation is never a terminal action. Create or update a tracking Issue (残置) for re-dispatch. Leaving a flaky test isolated without tracking is not acceptable.
3. **Unblock** other work by marking the test as isolated rather than leaving the suite red.

## Promotion to the full feature route (Type A)

If `debugging`'s Root Cause Classification is **Type A (AC Gap — 仕様/設計判断が必要)**, the flaky behavior is not a pure non-determinism defect: it requires a specification/design decision. **Leave the flaky lightweight route** and **promote to the full feature route**, reusing the existing `debugging → defining-requirements` chain (add the missing AC, then continue the 6-step flow). Type B (Test Gap) / Type C (Logic Error — including all flaky sub-axis categories) stay on the flaky route.

## Merge always passes the User gate (AL-1)

Merging is performed via `merging-and-deploying` and **always requires the User merge gate** (autopilot Iron Law AL-1). The flaky route never auto-merges — even though the route is lighter, the merge decision stays with the human.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Bug intake / triage | `bug` (reused, unedited) |
| Non-determinism root-cause classification | `debugging` (reused, unedited) |
| Determinization fix + iterative regression (反復赤→N 回連続緑) | `running-atdd-cycle` (reused, unedited) |
| Review | `reviewing-deliverables` (reused, unedited) |
| Merge + post-deploy regression | `merging-and-deploying` (reused, unedited) |
| Route orchestration (skip 3 / chain 5 / forward-chain override / Type A promotion) | **fixing-flaky-tests** (this skill) |

This skill **only binds** the existing skills; it does **not** redefine the reproduction methodology or diagnostic logic (zero duplication). It adds no new methodology to its own body.

## Integration

- **Upstream:** a flaky test report (auto via `bug`) or explicit `/atdd-kit:flaky-fix <issue>`.
- **Route determination:** `docs/methodology/route-eligibility.md` (SoT) decides flaky vs bugfix vs full route; recommendation only, no auto-routing.
- **Downstream:** `merging-and-deploying` (the User merge gate, on a near-green determinized fix).
