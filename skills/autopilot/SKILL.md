---
name: autopilot
description: "Use when you want to run an Issue in autopilot — autonomously converging its deliverables to near-green, with human involvement only at the start (AC approval) and the end (merge)."
---

# Autopilot

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

- **Explicit:** `/atdd-kit:autopilot <issue-number>` (e.g. `autopilot 24`).
- **Keyword-detected (confirm first):** on autopilot / 半自動運転 / 自律収束 intent, ask `Run autopilot on <issue>? Y/n` before starting.

## Input

- Issue number, with a **human-approved, immutable AC set** already produced via `defining-requirements` (壁打ち) + `extracting-user-stories` — the first human gate. If the AC is not approved, stop and route to that gate. autopilot never invents or approves its own AC.

## Human gates (exactly two — AL-1)

1. **Start — AC approval.** `defining-requirements` engages the human, the human approves the AC, and it is frozen as the immutable anchor.
2. **End — merge.** A human reviews the near-green result and merges. autopilot never merges.

## Output

| Artifact | Form |
|----------|------|
| Converged deliverables | the flow skills' artifacts, looped to the satisfaction oracle |
| Audit trail | `docs/issues/<NNN>-<slug>/autopilot-log.jsonl` (one JSONL line per iteration, AL-4) |

**Output language: Japanese (fixed).** Structural tokens (PASS/FAIL, AL ids, oracle terms) are kept verbatim.

## Mechanism — a Workflow loop over the flow skills

Invoking this skill opts into the **Workflow tool**. For each step S in `[extracting-user-stories, writing-plan-and-tests, running-atdd-cycle]`, loop `generate → review → fix`:

1. **generate** — run S's flow skill to produce or repair its artifact, anchored to the immutable approved AC.
2. **review** — run `reviewing-deliverables` (single-pass primitive, unchanged) → its structured verdict (`overall_correctness` + `findings[]`, each carrying `priority` and `evidence_ref`).
3. **deterministic AT gate (AL-3)** — when S produces an executable AT suite, `atGreen` is set from the **test command's exit code**, captured by running it — never from an LLM opinion of whether tests "would" pass.
4. **AC→AT coverage gate (AL-2)** — when S produces AT, a check **run in a context separate from the AT author** confirms the AT encode every approved AC; any uncovered AC is a P0. This is the external anchor that stops the loop from grading its own AT.
5. **satisfaction oracle** — `AND(atGreen [deterministic], coverageOk, overall_correctness == "correct", confirmed P0/P1 == 0)`. A finding with an absent / non-numeric `priority` is treated as **blocking** (fail-safe), and a confirmed P0/P1 blocks **regardless of `evidence_ref`** — AL-4 is fail-safe, never fail-open.
   - satisfied → advance to the next step.
   - not satisfied → feed the findings **verbatim** back into generate (fix) and re-loop.
6. **safety rails** (`lib/autopilot_convergence.sh`, AL-5) — record the iteration to the JSONL, then check the rails; a **non-zero `record_iteration`** (corrupt / empty fingerprint) is itself a halt. **Halt + escalate to a human** on any.

```js
export const meta = {
  name: 'autopilot',
  description: 'autopilot: loop the flow skills generate→review→fix until the satisfaction oracle holds, with safety rails',
  phases: [{ title: 'Generate' }, { title: 'Review' }, { title: 'AT-gate' }, { title: 'Coverage-gate' }, { title: 'Rails' }],
}

const NNN = args.issue
const STEPS = args.steps || ['extracting-user-stories', 'writing-plan-and-tests', 'running-atdd-cycle']
const MAX_ITERATIONS = args.maxIterations || {
  'extracting-user-stories': 4, 'writing-plan-and-tests': 4, 'running-atdd-cycle': 8,
}
// The step that produces an executable AT suite. For it (and only it) the
// deterministic AT gate (AL-3) and the AC→AT coverage gate (AL-2) run.
const AT_STEP = args.atStep || 'running-atdd-cycle'
const AT_COMMAND = args.atCommand || "the project's Acceptance Test command (e.g. `bats tests/acceptance/`)"
// Fail-closed precondition: the AT step must be one of the looped STEPS. If it
// is not, atRequired is false for every step and the AT + coverage gates vanish,
// degrading the oracle to a pure LLM opinion — so refuse to run.
if (!STEPS.includes(AT_STEP)) throw new Error(`AT_STEP "${AT_STEP}" not in STEPS — AT/coverage gates would be skipped`)
// The issue directory is slug-suffixed (docs/issues/<NNN>-<slug>/), not the bare
// number. The audit step resolves it by glob at write time and appends the log
// inside it; using the bare ${NNN} would write to a phantom dir and break AL-4.
const LOG_GLOB = `docs/issues/${NNN}-*/autopilot-log.jsonl`

// Consumer schema. findings items REQUIRE priority + evidence_ref so the oracle
// can never read an undefined priority as "not blocking" (fail-open). atGreen
// is NOT taken from the reviewer here — it comes from the deterministic gate.
const VERDICT_SCHEMA = {
  type: 'object',
  required: ['verdict', 'overall_correctness'],
  properties: {
    verdict: { type: 'string' },               // PASS | FAIL
    overall_correctness: { type: 'string' },    // correct | incorrect
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['priority', 'evidence_ref'],
        properties: {
          priority: { type: 'integer' },         // 0=blocker 1=major 2=minor 3=nit
          confidence: { type: 'number' },
          evidence_ref: { type: 'string' },       // AL-4: every finding carries one
          detail: { type: 'string' },
        },
      },
    },
  },
}

// Normalize an LLM-supplied priority; an absent / non-numeric value is treated
// as 0 (blocker) so a malformed finding can never slip through as "not blocking".
const priorityOf = (f) => {
  if (typeof f.priority === 'number') return f.priority
  const m = String(f.priority ?? '').match(/\d+/)
  return m ? Number(m[0]) : 0
}

for (const step of STEPS) {
  const max = MAX_ITERATIONS[step] || 4
  const atRequired = step === AT_STEP
  let it = 0
  for (;;) {
    it++
    // 1. generate / fix — run the EXISTING flow skill (not rewritten)
    await agent(`Run the ${step} flow skill for Issue #${NNN}, anchored to the immutable approved AC. If a prior review left findings, fix them verbatim.`, { label: `gen:${step}`, phase: 'Generate' })
    // 2. review — single-pass primitive, structured verdict
    const verdict = await agent(`Run reviewing-deliverables for Issue #${NNN}; return its structured verdict (overall_correctness + findings[], each with priority and evidence_ref).`, { label: `review:${step}`, phase: 'Review', schema: VERDICT_SCHEMA })
    // 3. DETERMINISTIC AT gate (AL-3) — atGreen is the test command's EXIT CODE,
    //    never an LLM opinion. Default false when AT is required and not run.
    let atGreen = !atRequired
    if (atRequired) {
      const at = await agent(`Run the executable Acceptance Test suite for Issue #${NNN} (${AT_COMMAND}). Actually execute it; report ONLY the command's integer exit code and green = (exit code === 0). Do NOT judge whether tests "would" pass.`, { label: `at-gate:${step}`, phase: 'AT-gate', schema: { type: 'object', required: ['exitCode', 'green'], properties: { exitCode: { type: 'integer' }, green: { type: 'boolean' }, log: { type: 'string' } } } })
      atGreen = at.exitCode === 0 && at.green === true
    }
    // 4. AC→AT coverage gate (AL-2) — separate context from the AT author.
    let coverageOk = !atRequired
    if (atRequired) {
      const cov = await agent(`In a context SEPARATE from the AT author, verify the executable Acceptance Tests for Issue #${NNN} encode EVERY approved AC in the immutable AC set (docs/issues/${NNN}-*/acceptance-tests.md + the approved AC). List uncovered AC; each is a P0.`, { label: `coverage:${step}`, phase: 'Coverage-gate', schema: { type: 'object', required: ['allCovered', 'uncovered'], properties: { allCovered: { type: 'boolean' }, uncovered: { type: 'array', items: { type: 'string' } } } } })
      coverageOk = cov.allCovered === true && (cov.uncovered || []).length === 0
    }
    const blocking = (verdict.findings || []).filter((f) => priorityOf(f) <= 1)
    // 5. satisfaction oracle — AL-3 deterministic AT AND AL-2 coverage AND
    //    reviewer correctness AND zero confirmed P0/P1 (fail-safe, not fail-open).
    const converged = atGreen && coverageOk && verdict.overall_correctness === 'correct' && blocking.length === 0
    // 6. AUDIT FIRST (AL-4) — record EVERY iteration (incl. the converged one)
    //    before deciding, so the JSONL is the complete external source of truth.
    //    record_iteration's full signature is <jsonl> <iteration> <step> <verdict> <fp>;
    //    a non-zero return (corrupt / empty fingerprint) is itself a halt.
    const rec = await agent(`Resolve the issue directory matching docs/issues/${NNN}-* (it exists) and append one audit line to its autopilot-log.jsonl (${LOG_GLOB}) via lib/autopilot_convergence.sh. Run EXACTLY: \`fp="$(printf '%s' "<the blocking findings text, verbatim>" | fingerprint)"\` then \`record_iteration "<resolved-log-path>" ${it} ${step} ${converged ? 'PASS' : 'FAIL'} "$fp"\`. Report recordOk = (record_iteration exit code === 0).`, { label: `audit:${step}`, phase: 'Rails', schema: { type: 'object', required: ['recordOk'], properties: { recordOk: { type: 'boolean' } } } })
    if (rec.recordOk !== true) return { status: 'COMPLETED_WITH_DEBT', step, reason: 'record-error', verdict }
    if (converged) { log(`${step}: converged at iteration ${it}`); break }
    // 7. safety rails (AL-5) — run each check and return its raw EXIT CODE; the
    //    HALT is computed in JS (not summarized by the LLM) so a mis-reported
    //    exit cannot fake 'none'. 0 = continue, non-zero = halt.
    const r = await agent(`Against the resolved autopilot-log.jsonl, run via lib/autopilot_convergence.sh: check_max_iterations ${it} ${max}; check_sameness "<log>"; check_stuck "<log>" 3. Report each one's integer exit code.`, { label: `rails:${step}`, phase: 'Rails', schema: { type: 'object', required: ['maxIterExit', 'samenessExit', 'stuckExit'], properties: { maxIterExit: { type: 'integer' }, samenessExit: { type: 'integer' }, stuckExit: { type: 'integer' } } } })
    const halt = r.maxIterExit !== 0 ? 'MAX_ITERATIONS' : r.samenessExit !== 0 ? 'sameness-detector' : r.stuckExit !== 0 ? 'stuck' : 'none'
    // COMPLETED_WITH_DEBT: hand unresolved findings to the human (AL-5)
    if (halt !== 'none') return { status: 'COMPLETED_WITH_DEBT', step, reason: halt, verdict }
  }
}
return { status: 'CONVERGED', steps: STEPS }
```

The rails (`fingerprint` / `record_iteration` / `check_sameness` / `check_stuck` / `check_max_iterations`) live in `lib/autopilot_convergence.sh` as the single, BATS-verified source — the workflow calls them rather than re-deriving the logic in JS. A non-`none` `halt` means **escalate to a human** with `COMPLETED_WITH_DEBT` recorded; autopilot never silently loops forever or fakes green.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Looping the flow skills to the satisfaction oracle | **autopilot** (this skill) |
| Each artifact's generation | the flow skills (unchanged) |
| The review verdict | reviewing-deliverables (single-pass primitive) |
| AC approval / merge (the two human gates) | the human |
| Parallel-session conflict, `in-progress` label | skill-gate |

This skill **does not** permanently change the flow skills, **does not** approve its own AC, and **does not** merge — merging is the human gate (AL-1).

## Integration

- **Upstream:** `defining-requirements` (the approved, immutable AC — the first human gate)
- **Downstream:** `merging-and-deploying` (the human merge gate, on a near-green Issue)
