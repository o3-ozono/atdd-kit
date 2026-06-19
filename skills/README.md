# Skills

Skills are auto-detected or workflow-chained behaviors that shape how Claude Code operates within a project. Each skill has a `SKILL.md` with trigger conditions and detailed instructions.

See [DEVELOPMENT.md](../DEVELOPMENT.md) for the distinction between skills and commands.

## Workflow Chain

The v1.0 ATDD flow is a 6-step chain. Each Issue gets its own directory under `docs/issues/<NNN>/`.

```
defining-requirements → extracting-user-stories → writing-plan-and-tests
  → running-atdd-cycle → reviewing-deliverables → merging-and-deploying
```

| Step | Skill | Deliverable in `docs/issues/<NNN>/` |
|------|-------|-------------------------------------|
| 1 | `defining-requirements` | `prd.md` |
| 2 | `extracting-user-stories` | `user-stories.md` |
| 3 | `writing-plan-and-tests` | `plan.md`, `acceptance-tests.md` |
| 4 | `running-atdd-cycle` | `tests/acceptance/AT-*.*` (draft → green) |
| 5 | `reviewing-deliverables` | review notes |
| 6 | `merging-and-deploying` | merged PR + post-deploy regression |

Resume mid-flow by invoking the skill for the next incomplete step. `skill-gate` routes Issue work to Step 1 (`defining-requirements`) and enforces **Iron Law #1**: no code editing without an Issue. Step 4 (`running-atdd-cycle`) starts from a `ready-to-go` Issue and switches it to `in-progress`.

## Skill List

### v1.0 Flow

| Skill | Trigger | Workflow Position |
|-------|---------|-------------------|
| [defining-requirements](defining-requirements/) | Step 1 of Issue work; routed by skill-gate | Discovery & Definition → PRD |
| [extracting-user-stories](extracting-user-stories/) | Step 2, chained from defining-requirements | User Story extraction |
| [writing-plan-and-tests](writing-plan-and-tests/) | Step 3, chained from extracting-user-stories | Plan + Acceptance Tests |
| [running-atdd-cycle](running-atdd-cycle/) | Step 4, manually invoked on `ready-to-go` Issues | ATDD implementation (draft → green) |
| [reviewing-deliverables](reviewing-deliverables/) | Step 5, after green | Review (Workflow-based dynamic, parallel, multi-round review) |
| [merging-and-deploying](merging-and-deploying/) | Step 6, after review PASS | Merge + post-deploy regression |
| [writing-design-doc](writing-design-doc/) | On-demand, conditional | Design document for non-trivial trade-offs |
| [launching-preview](launching-preview/) | On-demand | Local preview |
| [autopilot](autopilot/) | On-demand (autopilot) | Autonomous convergence loop over the flow skills — User gates at requirements approval (start), design approval (before ATDD), and merge (end); dialog economy (#254): asks only human-only decisions, batch-presents drafts; gate-rejection plumbing (#261): a non-'ok' design-gate comment rejects the whole set (partial approval is not approval) and re-runs the design phase with `rejectionFindings` args; step-scoped convergence checks (#272, #277): `check_sameness` / `check_stuck` filter by current step so cross-phase identical fingerprints do not trigger false halts, and the audit fingerprint embeds oracle state (`atGreen`, `coverageOk`, `uncovered`, `blocking`); FAIL-only population (#277): PASS rows are never part of the comparison population — `check_sameness` / `check_stuck` compare same-step FAIL rows only so design-gate re-entry and other convergence-then-re-open scenarios do not produce false halts; presentation channel (#267): deliverable bodies travel as the Draft PR diff, terminal/comments carry the PR link + decision points; diff-in-body (#275): gate messages carry the decision evidence inline — per-finding diff hunks on re-presentation, key decisions with file/line refs on first presentation, implementation diff (per-file stat + key hunks) at merge hand-off; impl phase model assignment (#311): all 7 impl agent() calls (gen / review / at-gate / coverage / audit / rails / audit-halt) carry `model: MODEL` where `MODEL = PHASE === 'impl' ? 'sonnet' : undefined`, so impl subagents default to Sonnet while design phase and orchestrator glue (`freeze:anchor`) inherit the session model; express precheck (#304): before Gate ①, evaluates the Issue against `docs/methodology/route-eligibility.md` express-eligible signals — express-eligible Issues receive a one-time pre-flight advisory ("express の方が低コスト。autopilot で続行しますか？") requiring explicit `ok` to continue, non-eligible Issues proceed silently; auto-route is never performed (AL-1: gate count stays at three); halt terminating record (#299): on convergence-failure halt (MAX_ITERATIONS / sameness-detector / stuck / ac-drift / log-integrity), the `audit-halt` agent calls `record_halt` in `lib/autopilot_convergence.sh` to append one terminating HALT record to the JSONL audit log (fields: outcome / step / reason / findings_digest as nested JSON array / timestamp) then commits the log file alone — `COMPLETED_WITH_DEBT` return value is kept alongside the JSONL record; non-convergence-failure return paths (record-error / rails-error / freeze-error / anchor-pin-failed) do not call `record_halt`; the HALT row does not increment the `recorded` counter and no integrity re-check runs after append ; hand-off mode (#318): `--hand-off` (full-autopilot only) collapses the gate signers — ①=queue pre-approval, ②=reviewer-oracle auto-approve, ③=merge coordinator — while a flagless run keeps the strict three gates unchanged; **merge-ready label produce (#329 / US-3):** on hand-off Gate ③ success, autopilot adds `merge-ready` GitHub label (`gh issue edit <issue> --add-label merge-ready`) so `full-autopilot-run.sh`'s `__default_result` can confirm it; this label add runs only when `FA_HANDOFF=1` is set — flagless (AL-1 three-gate) runs do not add the label |
| [full-autopilot](full-autopilot/) | On-demand (full-autopilot), queue drain | Multi-Issue, parallel, hands-off orchestrator over `autopilot` (#318, #329): drains a queue of `ready-to-go` (DoR + plan review PASS) Issues by dispatching parallel headless `autopilot --hand-off` workers and serially merging their results via a capacity-1 merge coordinator; human involvement narrows to the requirements 壁打ち that enqueues an Issue. **Dynamic queue (#329 / US-1):** `$FA_QUEUE_CMD` is re-evaluated on every slot-refill — issues added to `ready-to-go` after the session starts are picked up in the same run (startup-freeze removed). **Notify preflight (#329 / US-2):** on startup warns if `FA_NOTIFY_CMD` is unset; does not block. Wires `lib/lease-store.sh` (issue/merge lease), `lib/full-autopilot-dispatch.sh` (K-slot select), `lib/merge-coordinator.sh` (rebase→re-gate→merge→regression, auto-retry→escalate). Intake restricted to `ready-to-go` (safety valve). |

| [express](express/) | Explicit `/atdd-kit:express <issue>` only — no keyword auto-trigger | Documentation-grade Issue fast path: Issue → impl → CI → merge, skipping PRD/US/plan/AT/review |
| [fixing-bugs](fixing-bugs/) | On-demand bugfix route; explicit via `/atdd-kit:autofix <issue>` | Lightweight bugfix orchestration (#308): reuses existing skills only — chains `bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying`, skipping the three definition skills (`defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests`). Overrides `bug`'s hard-coded forward chain via orchestrator-driven invocation **without editing `bug`** (chained skills' Next Step is advisory under this route). Reproduction is confirmed platform-aware (web: `playwright-cli`/`verify` external skills; iOS: Xcode/simulator MCP + `sim-pool`; other: CLI/bats) and encoded as a failing test (赤→緑 oracle anchor). The middle User gate is specialized from design-approval to **cause-agreement** (approval target = root-cause classification + failing reproduction test; AL-1 三ゲート不変条件 preserved, gate count stays three); merge stays the User merge gate (never auto-merge). Type A (AC Gap) root causes promote to the full feature route via `debugging → defining-requirements`. Adds no new methodology — only binds existing skills. Route determination SoT: `docs/methodology/route-eligibility.md`; oracle/gate specialization: `docs/methodology/autopilot-iron-law.md` + `docs/methodology/autopilot-design-gate.md` |
| [fixing-flaky-tests](fixing-flaky-tests/) | On-demand flaky-test-fix route; explicit via `/atdd-kit:flaky-fix <issue>` | Lightweight flaky-test-fix orchestration (#322, sibling of fixing-bugs): reuses existing skills only — chains `bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying`, skipping the three definition skills. Overrides `bug`'s hard-coded forward chain via orchestrator-driven invocation **without editing `bug`**. Probabilistic reproduction confirmed platform-aware via N iterative runs (other: bats loop; web: `playwright-cli` external; iOS: Xcode/simulator MCP + `sim-pool`); failure rate recorded; single-run is not reproduction. Non-determinism categorized as `debugging` Type C sub-axis (timing / order / shared-state / external-dependency / resource-leak). Middle User gate specialized to **cause-agreement** (approval target = non-determinism classification + iterative failing anchor + failure rate; gate count stays three). Convergence oracle: N consecutive greens (determinization) + no regression; single-run green is not convergence. Quarantine judgment (platform-aware isolation markers + mandatory tracking Issue). Type A promotes to full feature route. Adds no new methodology — only binds existing skills. Route determination SoT: `docs/methodology/route-eligibility.md`; oracle/gate specialization: `docs/methodology/autopilot-iron-law.md` + `docs/methodology/autopilot-design-gate.md` |

### Infrastructure

| Skill | Trigger | Workflow Position |
|-------|---------|-------------------|
| [skill-gate](skill-gate/) | Auto-triggers on every user message | Skill enforcement gate + Issue routing; **route-eligibility mandatory check (#329 / US-4):** before routing any Issue, loads `docs/methodology/route-eligibility.md` and evaluates express / full-flow / bugfix signals — non-eligible route invocations (e.g. express for a behavior-change Issue) surface a mismatch warning; user may override explicitly |
| [session-start](session-start/) | Auto-invoked at session start | Session initialization |
| [bug](bug/) | Auto-triggers on bug/error keywords | Bug intake → ATDD flow |
| [debugging](debugging/) | Auto-triggers on bug reports, errors, crashes | Pre-fix root cause investigation |
| [skill-fix](skill-fix/) | Auto-triggers on skill name + intent verb; explicit via `/atdd-kit:skill-fix` | Background skill defect reporting |
| [sim-pool](sim-pool/) | Auto-triggers before iOS simulator tool calls | iOS simulator access management |
| [ui-test-debugging](ui-test-debugging/) | Auto-triggers on CI UI Test failures | CI UI Test failure diagnosis |

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Skills vs Commands, skill description field rules
- Each skill's `SKILL.md` — Full trigger conditions and instructions
- [agents/](../agents/) — Custom agent definitions placeholder (currently README only). Since #234, `reviewing-deliverables` generates its reviewer panel dynamically via the Workflow tool; the former fixed reviewer roster was removed in #271. The directory README also hosts the #259 model-assignment policy.
- [addons/](../addons/) — Platform-specific addon packages
