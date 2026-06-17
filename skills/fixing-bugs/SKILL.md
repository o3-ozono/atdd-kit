---
name: fixing-bugs
description: "Use when a bug/defect/error needs a minimal targeted fix on its own lightweight route, separate from the full 6-step feature flow. Explicit via /atdd-kit:autofix <issue>."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# fixing-bugs Skill — Lightweight bugfix Route (separate from the full feature route)

A thin **orchestration** skill for the bugfix category. It does **not** introduce a new methodology, step, or diagnostic logic — it **only reuses** existing skills, bundling them into a shorter chain tuned for defects. The reproduction methodology, root-cause diagnosis, ATDD, review, and merge all live in the existing skills; this skill just routes between them.

The full feature route formalizes every change into Connextra User Stories + Plan + AT spec. For a bug, that formalization gets in the way of going straight at the defect. So the bugfix route **skips** the three definition skills and chains the rest.

## Skill Chain (orchestrator-driven)

| # | Skill | Role on this route |
|---|-------|--------------------|
| 1 | `bug` | intake / Issue 化 / triage |
| 2 | `debugging` | Scientific Debugging で根本原因を診断・分類（Type A/B/C, evidence 付き） |
| 3 | `running-atdd-cycle` | 最小修正 + 回帰テスト（失敗再現テスト 赤→緑） |
| 4 | `reviewing-deliverables` | 成果物レビュー |
| 5 | `merging-and-deploying` | マージ + post-deploy 回帰（User gate 必須） |

**Skipped (full feature route only):** `defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests`. Reason: these formalize a change into a PRD → Connextra User Stories → Plan + AT spec; for a defect that formalization stops you from going straight at the bug's essence. The bugfix route reuses the remaining 5 skills as-is and **defines no new methodology** — it only binds the existing skills together (zero duplication).

## Forward-chain override (orchestrator-driven invocation)

The existing `bug` skill hard-codes a forward "Next Step" that invokes `defining-requirements` (`skills/bug/SKILL.md`, the bug chain routes into Step 1 of the 6-step flow). That directly conflicts with the bugfix route, which skips `defining-requirements`. The fix does **not** edit `bug` (or any chained skill — Non-Goal). Instead the override lives here:

- On the bugfix route, **`fixing-bugs` is the orchestrator** and drives each skill's Skill-tool invocation explicitly (**orchestrator-driven invocation**).
- Each chained skill's own **"Next Step"** is, under this route, **advisory only** (a hint about the next stage); the `fixing-bugs` chain definition above **overrides** that self-routing forward chain.
- Concretely: after `bug` completes, do **not** follow `bug`'s Next Step to `defining-requirements` — instead, per this chain, invoke `debugging` next.

This intercepts `bug`'s forward chain **without editing `bug`**. `bug` / `debugging` / `running-atdd-cycle` / `reviewing-deliverables` / `merging-and-deploying` SKILL.md files are left unedited (Non-Goal: no essential rewrite of the reused skills).

## Reproduction wiring (two layers)

### 1a. Reproduction confirmation (empirical, tool-driven)

Before encoding anything, **reproduce the defect with real tools**, platform-aware. Read `.claude/config.yml`'s `platform` and branch:

| platform | tool |
|----------|------|
| web | `playwright-cli` / `verify` (**external skills** — environment/global, not atdd-kit-owned) |
| iOS | Xcode / simulator MCP (**external tool/MCP**) + `sim-pool` (atdd-kit-owned) |
| other | CLI / script execution (bats 等) |

`playwright-cli` / `verify` / Xcode-simulator MCP are referenced as **external skills / external MCP only** — the bugfix route does **not** create or register them as atdd-kit-local skills, does not add them to `skills/README.md`, and generates no BATS structural test for them. Only `sim-pool` is an atdd-kit-owned skill. The `re-use only` contract applies to atdd-kit's internal skills; external references carry no structural-test expectation.

### 1b. Encode into a failing test

Encode the confirmed reproduction as an **executable failing test (赤)**. This failing test becomes the autopilot convergence oracle's **anchor**: it is **赤 before the fix** and must turn **緑 after the fix** (赤→緑). The anchor is a real, runnable artifact (not a description), so it is pin-able as the cause-agreement gate's approved deliverable (see below).

## cause-agreement gate (the bugfix route's middle User gate — AL-1 preserved)

The bugfix route writes no US/Plan/AT spec, so the standard **design-approval gate** has no US/plan/acceptance-tests deliverable to anchor. Rather than remove a gate (forbidden by AL-1), the middle gate is **specialized to a cause-agreement gate**: its approval target is **`debugging` Step 5's root-cause classification (Type A/B/C, evidence 付き) + the failing reproduction test (赤)**. `debugging` already ends Step 5 with a `Proceed to fix?` human confirmation (reused). On the bugfix route that confirmation **is** the design-gate's role.

**ATDD (the minimal fix) never starts before the cause-agreement gate.** The approval target is non-empty (classification + failing repro test), so AL-1's "ATDD never starts before that gate" holds. Full spec lives in `docs/methodology/autopilot-iron-law.md` (AL-1 specialization) and `docs/methodology/autopilot-design-gate.md` (presentation contract); both docs agree the bugfix middle gate is the **cause-agreement** gate.

## Promotion to the full feature route (Type A)

If `debugging`'s Root Cause Classification is **Type A (AC Gap — 仕様/設計判断が必要)**, the bug is not a pure defect: it needs a specification/design decision. **Leave the bugfix lightweight route** and **promote to the full feature route**, reusing the existing `debugging → defining-requirements` chain (add the missing AC, then continue the 6-step flow). Type B (Test Gap) / Type C (Logic Error) stay on the bugfix route (`debugging → running-atdd-cycle` with a regression test).

## Merge always passes the User gate (User-Constraint2)

Merging is performed via `merging-and-deploying` and **always requires the User merge gate** (autopilot Iron Law AL-1). The bugfix route never auto-merges — even though the route is lighter, the merge decision stays with the human.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Bug intake / triage | `bug` (reused, unedited) |
| Reproduction methodology + root-cause classification | `debugging` (reused, unedited) |
| Minimal fix + regression test (赤→緑) | `running-atdd-cycle` (reused, unedited) |
| Review | `reviewing-deliverables` (reused, unedited) |
| Merge + post-deploy regression | `merging-and-deploying` (reused, unedited) |
| Route orchestration (skip 3 / chain 5 / forward-chain override / Type A promotion) | **fixing-bugs** (this skill) |

This skill **only binds** the existing skills; it does **not** redefine the reproduction methodology or diagnostic logic (zero duplication). It adds no new methodology to its own body.

## Integration

- **Upstream:** a bug report (auto via `bug`) or explicit `/atdd-kit:autofix <issue>`.
- **Route determination:** `docs/methodology/route-eligibility.md` (SoT) decides bugfix vs full route; recommendation only, no auto-routing.
- **Downstream:** `merging-and-deploying` (the User merge gate, on a near-green fix).
