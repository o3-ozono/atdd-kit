---
name: batch-discovery
description: "Use when multiple Issues need front-loaded batch requirements 壁打ち and parallel background preparation to ready-to-go, with human involvement at a constant 1-2 gates regardless of Issue count."
---

# batch-discovery — Batch 壁打ち + Parallel Background Preparation

A **preparation-phase skill** that front-loads the requirements 壁打ち for N Issues into a single human interaction, then drives each Issue to `ready-to-go` in parallel headless workers. The consumption phase (draining the queue) is handed off to `full-autopilot`; this skill does **not** rewrite `full-autopilot` or any of the core flow skills (疎結合 / C3).

## Trigger

- **Explicit:** `/atdd-kit:batch-discovery <issue...> [--parallel K]`
- **Keyword-detected (confirm before invoking):** When user mentions "batch-discovery", "一括 ready-to-go", "複数 Issue 準備", ask `Run batch-discovery on <issues>? Y/n` before starting. Auto-invocation without confirmation is forbidden.

## Input

- One or more Issue numbers.
- Optional: `--parallel K` — max concurrent worker slots (default 2).
- No pre-conditions required beyond the Issues being open and scoped.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Batch 壁打ち (N Issues → 1 human session) | **batch-discovery** (this skill) |
| PRD → US → plan+AT → reviewing-deliverables PASS → Draft PR → `ready-to-go` | **headless workers** (autopilot per Issue, dispatched by this skill) |
| Queue drain (consuming `ready-to-go` Issues) | `full-autopilot` (unmodified, C3 maintained) |
| Issue/merge lease management | `lib/lease-store.sh` (reused, unmodified) |
| K-slot dispatch selection | `lib/full-autopilot-dispatch.sh` (reused, unmodified) |
| Worktree isolation + plugin settings seeding | `lib/full-autopilot-run.sh` `__seed_worktree_settings` (reused, unmodified) |

**batch-discovery does not rewrite `full-autopilot` or any chained skill** — it is a thin preparation-phase orchestrator that hands ready Issues to the existing queue.

## Human Gate Map (AL-1 alignment)

| Gate | batch-discovery mapping | Count |
|------|------------------------|-------|
| Gate ①: requirements approval | Front-loaded cross-Issue 壁打ち — 1 human session, all N Issues at once | 1 (constant, not per-Issue) |
| Gate ② equivalent: design approval | Selective final approval — present only "overturnable findings" (see below); skip entirely if zero findings | 0 or 1 (constant) |
| Gate ③: merge | `full-autopilot` merge coordinator — **unmodified, full-autopilot owns this gate** | unchanged |

**Total human interaction: constant 1–2 sessions regardless of N.** Per-Issue sequential 壁打ち is explicitly excluded (CS-1: count must be non-proportional to N).

Gate ③ is not owned by batch-discovery. full-autopilot's three-gate invariant (AL-1) is **unchanged** after batch-discovery hands off the Issues.

## Flow

### Phase 1: Autonomous loading

1. For each target Issue, read the Issue body and any existing `docs/issues/<NNN>/` artifacts.
2. **Autonomously draft** all requirements, goals, and constraints that can be derived from the Issue text and related docs — **do not ask the human about these** (Dialog economy / #254 extended to N Issues).
3. Extract only the **human-only decision points** from each Issue:
   - Tradeoffs: competing technical approaches where cost/benefit cannot be resolved from requirements alone
   - Intentional cut-corners (意図的割り切り): scope reductions that are value judgements
   - Scope exclusions: explicitly out-of-scope items that could legitimately be in scope
   - Risk tolerance: acceptable degradation, error rates, latency ceilings
   - Acceptance criteria: pass/fail thresholds only a human can set

### Phase 2: Cross-Issue batched 壁打ち (Gate ①)

4. Group the extracted decision points by **decision axis** (not by Issue) — tradeoffs together, risk tolerances together, etc. Assign axes to `AskUserQuestion` slots (max 4 questions per message). If axes exceed 4, split into additional messages but keep message count proportional to the **number of axes** (a constant-order quantity), never to N.
5. Present the batched questions in a **single human session** listing all N Issues. Wait for the human's answers before proceeding.
6. Apply the human's answers to update each Issue's autonomous draft.

### Phase 3: Parallel worker dispatch

7. For each Issue with resolved questions, acquire an issue-lease via `lib/full-autopilot-dispatch.sh select <K-active> <issue...>`:
   - `select` takes at most K slots.
   - Issues already claimed by another session (busy) are skipped.
   - K is the `--parallel` argument (default 2).
8. For each selected Issue, create an isolated worktree and **seed plugin settings before launching**:
   ```
   # Seed (lib/full-autopilot-run.sh __seed_worktree_settings equivalent)
   # Copies .claude/settings.local.json (enabledPlugins + extraKnownMarketplaces) into worktree.
   # WITHOUT seeding, 'Unknown command: /atdd-kit:autopilot' kills the worker immediately.
   FA_HANDOFF=1 claude -p "/atdd-kit:autopilot <issue> --hand-off" \
     --session-id <uuid> --output-format json \
     --permission-mode acceptEdits \
     > <worker-out>.json 2>&1 < /dev/null
   ```
   Worker goal: **PRD → US → plan+AT → reviewing-deliverables PASS → Draft PR → `ready-to-go`**.
9. Monitor for worker completion. On completion, read `<worker-out>.json` (`is_error` / `terminal_reason`).
10. **Lease release (3 paths — all must release):**
    1. Normal completion → `lib/lease-store.sh release issue <issue> <self>` immediately.
    2. Worker failure / timeout → same `release` immediately; re-queue if needed.
    3. Dispatcher crash (cannot call `release`) → lease **TTL (`LEASE_TTL_LOCAL`)** is the last line of defense: stale leases are auto-reclaimed to prevent permanent slot starvation.
11. When a slot opens (worker completes), refill from remaining Issues (back to step 7).

### Phase 4: Implementation ordering (manifest-based lightweight sequencing)

12. When Issues have a keystone→downstream dependency, record the implementation order in a **dedicated manifest file** for this batch run (ordered list of Issue numbers). The dispatcher reads this manifest to set the `select` input order, ensuring keystone Issues are dispatched before their dependents.
    - Manifest path: `docs/issues/batch-<timestamp>/manifest.json` (or caller-specified path).
    - Format: `{"order": [<issue1>, <issue2>, ...], "rationale": "<brief explanation>"}`.
    - If no manifest exists or an Issue in the manifest is no longer open/in-scope, dispatcher falls back to default (oldest-first) order with a warning.
    - **Non-Goal: full barrier / dynamic dependency resolution** — only the lightweight recorded-order approach is adopted (see `design-doc.md` D3 / Non-Goals).

### Phase 5: Selective final approval (Gate ② equivalent)

13. After all workers complete their reviewing-deliverables PASS phase, collect **overturnable findings** from the reviewer-oracle output:
    - Findings of **kind = tradeoff, intentional-cut, or scope-exclusion** are promoted to the final approval set (D2 from `design-doc.md`).
    - Pure-technical PASS findings and trivial fixes are **not** promoted.
    - High-priority findings outside these three kinds are treated as a supplement (secondary filter).
14. If promoted findings are **zero**: skip Gate ② entirely — proceed to `ready-to-go` without another human session.
15. If promoted findings are **non-zero**: present them in a single consolidated message (all Issues, all promoted findings). Gate ② is **one session maximum**. Do not present the entire design deliverables for approval — only the selected overturnable findings.
16. Add `ready-to-go` label to Issues that pass Gate ② (or skip Gate ② if zero findings).

## Non-Goals

- **Full barrier / dynamic dependency resolution**: only lightweight order-recording (recorded-order approach, not a full barrier or dynamic dependency graph).
- **Rewriting `full-autopilot` or any flow skill**: batch-discovery is a preparation-phase thin orchestrator; consumption is full-autopilot's responsibility.
- **Removing the AC approval gate (false-green prevention)**: the cross-Issue 壁打ち is the batch-aggregate of Gate ①; it does not remove the gate.
- **GitHub webhook queue enqueue**: out of scope (full-autopilot #329 dynamic queue is sufficient).

## Integration

- **Upstream:** explicit `/atdd-kit:batch-discovery <issues>` invocation.
- **Downstream:** Issues with `ready-to-go` label enter the `full-autopilot` queue and are drained by `full-autopilot`.
- **Libs reused (unmodified):** `lib/full-autopilot-dispatch.sh`, `lib/lease-store.sh`, `lib/full-autopilot-run.sh`.
- **Iron Law:** Gate ③ (merge) stays with `full-autopilot`'s merge coordinator — batch-discovery does not touch merge. AL-1 three-gate invariant is **unchanged**.
