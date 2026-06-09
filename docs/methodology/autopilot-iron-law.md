> **Loaded by:** `autopilot` skill; referenced from `rules/atdd-kit.md` and `docs/issues/246-autopilot-revival/design-doc.md`.

# The autopilot Iron Law

The standard Iron Laws (`rules/atdd-kit.md`) govern **human-driven** work: one Issue, one PR, a human approving every Acceptance Criterion before code is written. **autopilot** — the autonomous convergence loop owned by the `autopilot` skill — is structurally different. It *generates → reviews → fixes* a deliverable on its own and iterates until a satisfaction oracle is met. A human does not approve each iteration, and one convergence cycle deliberately produces several deliverables at once.

So some standard Iron Laws cannot hold verbatim inside autopilot. Rather than treat every such case as a violation to suppress, autopilot **accepts** the conflict and is governed instead by the **autopilot Iron Law** below — a stricter, purpose-built law that replaces the conflicting standard clauses *only while autopilot is running*. Outside autopilot, the standard Iron Law is unchanged and supreme.

## Relationship to the standard Iron Law

| Standard Iron Law | Inside autopilot |
|-------------------|------------------|
| #1 No code edits without an Issue | **Unchanged.** autopilot always runs against one Issue. |
| #2 No implementation without approved ACs | **Replaced by AL-2.** ACs are approved once at discover; iterations anchor to that immutable set instead of re-approving each loop. |
| #3 No completion claims without fresh verification evidence | **Strengthened by AL-3 / AL-4.** Completion requires the satisfaction-oracle AND gate, not a self-assessment. |
| #4 bug loads `docs/specs/<slug>.md` before AC judgement | **Unchanged.** |
| "1 PR = 1 thing" (Commits/PRs) | **Relaxed by AL-6.** One convergence cycle = one Issue's deliverable set. |

## The law (AL-1 … AL-6)

### AL-1 — Two human gates, fixed
The only human approval gates are **discover (AC approval)** and **merge**. At these two points the standard Iron Law is fully in force. autopilot must not silently remove, automate, or route around either gate.

### AL-2 — Immutable AC anchor (replaces standard #2)
An iteration may write implementation without a fresh human AC approval **iff** it is traceable to the **immutable** AC set a human approved at discover. Precondition: an **AC→AT coverage gate** — run in a context separate from the AT author — confirms the generated Acceptance Tests encode every approved AC; any uncovered AC is a P0 finding. The AC set is frozen *after* it is approved; autopilot may never edit it. This freeze is **enforced**, not merely declared: a sha256 of the approved AC (prd.md + user-stories.md) is pinned at loop start (`pin_anchor`) and re-checked every iteration (`check_pin`); any drift halts the loop (`ac-drift`), so autopilot cannot weaken the anchor it grades itself against.

### AL-3 — Satisfaction-oracle AND gate (strengthens standard #3)
A deliverable is "done" only when `AND(executable AT green, AC→AT coverage green [AL-2], reviewer verdict.overall_correctness = correct, confirmed P0/P1 findings = 0)` holds. Pass/fail of lint/test/AT is decided by the **deterministic gate** (CI / code), never by asking an LLM whether tests "would" pass. No completion claim without this evidence.

### AL-4 — Mandatory evidence_ref + auto-demote false-green
Every finding carries an `evidence_ref`: a failing-AT name / log path, or a quoted line from the immutable AC/PRD, or a human-comment URL. A PASS with no backing reviewer evidence is **auto-demoted to FAIL and re-run**. Every iteration's verdict is appended to `docs/issues/<NNN>-<slug>/autopilot-log.jsonl` as the external source of truth and audit trail.

### AL-5 — Fail safe
autopilot halts and escalates to a human on non-convergence, budget overrun, or repeated identical failure. Mechanisms: `MAX_ITERATIONS` per step, a **sameness-detector** (normalized sha256 fingerprint identical twice in a row), **stuck detection** (no progress across a window of 3), and `COMPLETED_WITH_DEBT` (record unresolved findings and hand to a human). Silent infinite loops and silent fake-green are structurally impossible.

### AL-6 — One convergence cycle may produce many deliverables (relaxes "1 PR = 1 thing")
Inside the loop, one cycle may produce a whole Issue's deliverable set (PRD → US → plan → AT → code) in one PR. The "one thing" discipline is preserved at the human **merge** gate, where a person reviews the near-green result as a whole.

## Skills are unchanged; only their role shifts under autopilot

autopilot does not fork or rewrite the flow skills. Each flow skill (`defining-requirements` … `reviewing-deliverables`) keeps its normal behavior. What changes **only while autopilot runs** is *where the human gate sits*: outside autopilot a human reviews each step; under autopilot the human gates collapse to AC approval (start) and merge (end), and the in-between steps are looped autonomously. This is why autopilot is implemented as a **thin orchestrator** (`autopilot`) over the existing skills rather than as edits to them — the skills' role is mode-dependent, their code is not. (`reviewing-deliverables`'s machine-readable verdict is a backward-compatible addition: non-autopilot callers ignore it.)

## Why these overrides are legitimate (not rationalization)

The standard Iron Law exists to keep a human in control of *what gets built* and *whether it is correct*. autopilot keeps both: **what** is anchored to the human-approved immutable AC (AL-1, AL-2), and **whether it is correct** is gated by an objective AND oracle plus auditable evidence (AL-3, AL-4), with a guaranteed human-escalation exit (AL-5). The overrides relax *how often a human signs off mid-loop*, not *whether a human owns the boundaries*. This is the same boundary the strongest field players keep (Anthropic: *"Claude does not approve or block PRs"*; OpenAI: *"a support tool, not a replacement"*) — see `docs/issues/246-autopilot-revival/research.md`.
