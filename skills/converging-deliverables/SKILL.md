---
name: converging-deliverables
description: "Use when you want to run an Issue in autopilot — autonomously converging its deliverables to near-green, with human involvement only at the start (AC approval) and the end (merge)."
---

# Converging Deliverables (autopilot)

The **autopilot** mode of atdd-kit. It does **not** replace the 6-step flow and does **not** rewrite the flow skills. It *runs the existing flow skills* — `extracting-user-stories` → `writing-plan-and-tests` → `running-atdd-cycle` → `reviewing-deliverables` — and narrows human involvement to **two gates only**: **AC approval** at the start and **merge** at the end. Everything between is looped `generate → review → fix` until a satisfaction oracle holds.

The flow skills are **not permanently changed**; their role (specifically, where the human gate sits) changes **only under autopilot**. See `docs/methodology/autopilot-iron-law.md`.

**Scope ends at a near-green Issue handed to the human merge gate.** Merging is never automated.

## autopilot Iron Law (overrides the standard Iron Law in this mode)

While autopilot runs, the standard Iron Laws (`rules/atdd-kit.md`) are overridden by the **autopilot Iron Law** (`docs/methodology/autopilot-iron-law.md`, AL-1…AL-6):

- **AL-1** human gates = AC approval + merge, fixed.
- **AL-2** iterations anchor to the immutable approved AC instead of re-approving each loop (precondition: AC→AT coverage gate green).
- **AL-3** "done" = the satisfaction-oracle AND gate; deterministic gates decide AT/lint/test.
- **AL-4** every finding needs an `evidence_ref`; an unbacked PASS auto-demotes; verdicts persist to JSONL.
- **AL-5** the loop fails safe via the rails below.
- **AL-6** one convergence cycle may produce a whole Issue's deliverables.

## Trigger

- **Explicit:** `/atdd-kit:converging-deliverables <issue-number>` (colloquially "autopilot <issue>").
- **Keyword-detected (confirm first):** on autopilot / 半自動運転 / 自律収束 intent, ask `Run converging-deliverables (autopilot) on <issue>? Y/n` before starting.

## Input

- Issue number, with a **human-approved, immutable AC set** already produced via `defining-requirements` (壁打ち) + `extracting-user-stories` — the first human gate. If the AC is not approved, stop and route to that gate. autopilot never invents or approves its own AC.

## Human gates (exactly two — AL-1)

1. **Start — AC approval.** `defining-requirements` engages the human, the human approves the AC, and it is frozen as the immutable anchor.
2. **End — merge.** A human reviews the near-green result and merges. autopilot never merges.

## Output

| Artifact | Form |
|----------|------|
| Converged deliverables | the flow skills' artifacts, looped to the satisfaction oracle |
| Audit trail | `docs/issues/<NNN>/autopilot-log.jsonl` (one JSONL line per iteration, AL-4) |

**Output language: Japanese (fixed).** Structural tokens (PASS/FAIL, AL ids, oracle terms) are kept verbatim.

## Mechanism — a Workflow loop over the flow skills

Invoking this skill opts into the **Workflow tool**. For each step S in `[extracting-user-stories, writing-plan-and-tests, running-atdd-cycle]`, loop `generate → review → fix`:

1. **generate** — run S's flow skill to produce or repair its artifact, anchored to the immutable approved AC.
2. **review** — run `reviewing-deliverables` (single-pass primitive, unchanged) → its structured verdict (`overall_correctness` + `findings[]` carrying `evidence_ref`).
3. **satisfaction oracle** — `AND(executable AT green [when S has AT], overall_correctness == "correct", P0/P1 findings == 0)`. Deterministic gates (CI / code) decide AT / lint / test; the LLM never re-judges them.
   - satisfied → advance to the next step.
   - not satisfied → feed the findings **verbatim** back into generate (fix) and re-loop.
4. **safety rails** (`lib/autopilot_convergence.sh`, AL-5) — record the iteration to the JSONL, then check the rails; **halt + escalate to a human** on any.

```js
export const meta = {
  name: 'converging-deliverables',
  description: 'autopilot: loop the flow skills generate→review→fix until the satisfaction oracle holds, with safety rails',
  phases: [{ title: 'Generate' }, { title: 'Review' }, { title: 'Gate' }],
}

const NNN = args.issue
const STEPS = args.steps || ['extracting-user-stories', 'writing-plan-and-tests', 'running-atdd-cycle']
const MAX_ITERATIONS = args.maxIterations || {
  'extracting-user-stories': 4, 'writing-plan-and-tests': 4, 'running-atdd-cycle': 8,
}
const LOG = `docs/issues/${NNN}/autopilot-log.jsonl`

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['verdict', 'overall_correctness'],
  properties: {
    verdict: { type: 'string' },               // PASS | FAIL
    overall_correctness: { type: 'string' },    // correct | incorrect
    atRequired: { type: 'boolean' },
    atGreen: { type: 'boolean' },
    findings: { type: 'array', items: { type: 'object' } }, // {priority,confidence,evidence_ref,...}
  },
}

for (const step of STEPS) {
  const max = MAX_ITERATIONS[step] || 4
  let it = 0
  for (;;) {
    it++
    // 1. generate / fix — run the EXISTING flow skill (not rewritten)
    await agent(`Run the ${step} flow skill for Issue #${NNN}, anchored to the immutable approved AC. If a prior review left findings, fix them verbatim.`, { label: `gen:${step}`, phase: 'Generate' })
    // 2. review — single-pass primitive, structured verdict
    const verdict = await agent(`Run reviewing-deliverables for Issue #${NNN}; return its structured verdict (overall_correctness + findings[] with evidence_ref).`, { label: `review:${step}`, phase: 'Review', schema: VERDICT_SCHEMA })
    // 3. satisfaction oracle: AND(AT green, verdict correct, P0/P1 == 0)
    const blocking = (verdict.findings || []).filter((f) => f.evidence_ref && f.priority <= 1)
    const atOk = !verdict.atRequired || verdict.atGreen
    if (atOk && verdict.overall_correctness === 'correct' && blocking.length === 0) {
      log(`${step}: converged at iteration ${it}`); break
    }
    // 4. safety rails — record then check; halt + escalate on any (delegated to the bash lib)
    //    lib/autopilot_convergence.sh: fingerprint | record_iteration | check_sameness | check_stuck | check_max_iterations
    const rails = await agent(`Append this iteration to ${LOG} via lib/autopilot_convergence.sh (record_iteration + fingerprint of the blocking findings), then run check_max_iterations ${it} ${max}, check_sameness, and check_stuck (window 3). Report which rail, if any, returned non-zero (halt) — value one of: MAX_ITERATIONS | sameness-detector | stuck | none.`, { label: `rails:${step}`, phase: 'Gate', schema: { type: 'object', required: ['halt'], properties: { halt: { type: 'string' } } } })
    if (rails.halt !== 'none') {
      // COMPLETED_WITH_DEBT: hand unresolved findings to the human (AL-5)
      return { status: 'COMPLETED_WITH_DEBT', step, reason: rails.halt, verdict }
    }
  }
}
return { status: 'CONVERGED', steps: STEPS }
```

The rails (`fingerprint` / `record_iteration` / `check_sameness` / `check_stuck` / `check_max_iterations`) live in `lib/autopilot_convergence.sh` as the single, BATS-verified source — the workflow calls them rather than re-deriving the logic in JS. A non-`none` `halt` means **escalate to a human** with `COMPLETED_WITH_DEBT` recorded; autopilot never silently loops forever or fakes green.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Looping the flow skills to the satisfaction oracle | **converging-deliverables** (this skill) |
| Each artifact's generation | the flow skills (unchanged) |
| The review verdict | reviewing-deliverables (single-pass primitive) |
| AC approval / merge (the two human gates) | the human |
| Parallel-session conflict, `in-progress` label | skill-gate |

This skill **does not** permanently change the flow skills, **does not** approve its own AC, and **does not** merge — merging is the human gate (AL-1).

## Integration

- **Upstream:** `defining-requirements` (the approved, immutable AC — the first human gate)
- **Downstream:** `merging-and-deploying` (the human merge gate, on a near-green Issue)
