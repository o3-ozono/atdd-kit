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
| [autopilot](autopilot/) | On-demand (autopilot) | Autonomous convergence loop over the flow skills — human gates at requirements approval (start), design approval (before ATDD), and merge (end); dialog economy (#254): asks only human-only decisions, batch-presents drafts; gate-rejection plumbing (#261): a non-'ok' design-gate comment rejects the whole set (partial approval is not approval) and re-runs the design phase with `rejectionFindings` args; step-scoped convergence checks (#272): `check_sameness` / `check_stuck` filter by current step so cross-phase identical fingerprints do not trigger false halts, and the audit fingerprint embeds oracle state (`atGreen`, `coverageOk`, `uncovered`, `blocking`); presentation channel (#267): deliverable bodies travel as the Draft PR diff, terminal/comments carry the PR link + decision points; diff-in-body (#275): gate messages carry the decision evidence inline — per-finding diff hunks on re-presentation, key decisions with file/line refs on first presentation, implementation diff (per-file stat + key hunks) at merge hand-off |

| [express](express/) | Explicit `/atdd-kit:express <issue>` only — no keyword auto-trigger | Documentation-grade Issue fast path: Issue → impl → CI → merge, skipping PRD/US/plan/AT/review |

### Infrastructure

| Skill | Trigger | Workflow Position |
|-------|---------|-------------------|
| [skill-gate](skill-gate/) | Auto-triggers on every user message | Skill enforcement gate + Issue routing |
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
