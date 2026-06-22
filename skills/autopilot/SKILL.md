---
name: autopilot
description: "Use when you want to run an Issue in autopilot — autonomously converging its deliverables to near-green, with User gates at requirements approval (start), design approval (before ATDD), and merge (end)."
---

# Autopilot

The **autopilot** mode of atdd-kit. It does **not** replace the 6-step flow and does **not** rewrite the flow skills. It *runs the existing flow skills* — `extracting-user-stories` → `writing-plan-and-tests` → `running-atdd-cycle`, with `reviewing-deliverables` as the in-loop reviewer — and narrows human involvement to **three gates**: **requirements approval** at the start, **design approval** before any implementation, and **merge** at the end. Between gates, everything is looped `generate → review → fix` until a satisfaction oracle holds. The flow skills are **not permanently changed**; their role (specifically, where the User gate sits) changes **only under autopilot**. See `docs/methodology/autopilot-iron-law.md`. **Scope ends at a near-green Issue handed to the User merge gate.** Merging is never automated.

## autopilot Iron Law (overrides the standard Iron Law in this mode)

While autopilot runs, the standard Iron Laws (`rules/atdd-kit.md`) are overridden by the **autopilot Iron Law** (`docs/methodology/autopilot-iron-law.md`, AL-1…AL-6). Full law text in that doc; key pointers: AL-1 fixes the three User gates; AL-2 enforces immutable per-phase anchors; AL-3/AL-4 gate "done" on deterministic evidence; AL-5/AL-6 govern fail-safe rails and convergence scope.

## Trigger

- **Explicit:** `/atdd-kit:autopilot <issue-number>` (e.g. `autopilot 24`).
- **Keyword-detected (confirm first):** on autopilot / 半自動運転 / 自律収束 intent, ask `Run autopilot on <issue>? Y/n` before starting.

## Input

- Issue number, with a **human-approved PRD** already produced via `defining-requirements` (壁打ち) — the first User gate. If the PRD is not approved, stop and route to that gate. autopilot never invents or approves its own requirements.

## Express precheck — pre-flight advisory (before Gate ①)

Evaluate the Issue against `docs/methodology/route-eligibility.md` express-eligible signals before Gate ①. **Auto-route is never performed** — do not switch to `express` automatically; the User gates stay at three (exactly three — AL-1 invariant).

- **Express-eligible** (doc-grade, no behavior change): present **once** — "この Issue は express の方が低コストです。autopilot で続行しますか？（ok で続行）" — and wait. Without an explicit `ok`, do not proceed. This advisory does not count toward the three User gates (AL-1).
- **Not express-eligible**: no message, proceed silently.
- **bugfix route (#308):** consult `docs/methodology/route-eligibility.md` (bugfix Route Signals) for whether the Issue takes the `fixing-bugs` lightweight route (skips the three definition skills; middle gate specialized to **cause-agreement**). Logic lives in route-eligibility.md (SoT); this skill only references it — recommendation only, no auto-route (AL-1).

## User gates (exactly three — AL-1)

1. **Start — requirements approval.** `defining-requirements` engages the human in 壁打ち (run it per Dialog economy below), the human approves the PRD, and it is frozen as the design phase's immutable anchor.
2. **Middle — design approval.** After the design phase converges `user-stories.md` / `plan.md` / `acceptance-tests.md` to near-green, autopilot **stops and presents them to the human** (one batch presentation — Dialog economy below). Explicit approval freezes the design anchor and unlocks the impl phase — ATDD never starts before this gate. Rejection comments re-enter the design loop as findings (`evidence_ref` = the human comment), carried into the design-phase re-invocation as `rejectionFindings` args (#261, Flow step 3); MAX_ITERATIONS restarts (human intervention = a new convergence cycle) while sameness history is kept.
3. **End — merge.** A human reviews the near-green result and merges. autopilot never merges. **Hand-off mode — `--hand-off` (full-autopilot only, #318):** honor する前に必ず `FA_HANDOFF=1` マーカーを検査する hard precondition — **マーカーが無い起動では `--hand-off` を無視し AL-1 厳密3ゲートで進める**（launcher が `FA_HANDOFF=1 claude -p …` で inline 設定・永続 export しない。**フラグ無し起動も当然 AL-1 のまま**）。honor 時のみ担い手が移る: ①=queue 事前承認 / ②=**reviewer-oracle**（AL-3/AL-4）自動承認（人間は Draft PR で override）/ ③=autopilot は merge せず `merge-ready` で手放し coordinator へ。手放し成功時は対象 Issue に `merge-ready` GitHub ラベルを付与する: `gh issue edit <issue> --add-label merge-ready`（`FA_HANDOFF=1` マーカーが在る起動のみ — 通常起動（AL-1 厳密3ゲート）ではラベル付与経路を起動しない）。詳細 `docs/methodology/autopilot-iron-law.md` §AL-1 under full-autopilot。

## Dialog economy — all human-facing dialog under autopilot (#254)

This governs all human-facing dialog under autopilot: the Gate ① requirements 壁打ち, the design-gate presentation, and everything between gates.

- **Ask ONLY what a human alone can decide**: diverging design judgments (trade-off / deliberate 割り切り), scope changes (additions or cuts), and the Outcome pass/fail criteria. Bundle them into the fewest questions — at most one batched question message per gate interaction.
- **Never ask section-by-section** confirmation of draft content derivable from the Issue body or context (= the Issue body, its linked references, and this conversation). *Derivable* means mechanically reconstructable from facts already stated there without a value judgment — e.g. the affected-file list quoted in the Issue is derivable; choosing between two defensible scope cuts is not (ask it). When derivability is genuinely uncertain, it is a judgment call — ask. Draft everything derivable and **batch-present** the whole draft in one message; approval or send-back happens once per fixed gate (PRD approval / design approval / merge).
- `defining-requirements`' "Each section step is one question at a time" stays the normal-flow (non-autopilot) design; under autopilot only, this directive overrides that cadence (C1: the flow skill file is never edited). The gate count stays fixed (AL-1) — what is removed is only the micro-confirmations between and inside gates, never a gate.
- **Presentation channel (#267)**: at Gate ① (requirements approval) and Gate ② (design approval) alike, deliverable bodies are committed and pushed to the work branch and presented as the **Draft PR diff**. The terminal and Issue/PR comments carry only the **PR link + the points needing a human decision** — never the full deliverable body. Full-channel sync of approval requests and state notifications (same content in terminal + GitHub) is kept. Diff-in-body (#275, Flow step 3/5) complements — does not override — this rule: the gate message additionally carries the **decision evidence** inline (per-finding diff hunks on re-presentation, key decisions on first presentation), which is never the full deliverable body.

## Output

| Artifact | Form |
|----------|------|
| Converged deliverables | the flow skills' artifacts, looped to the satisfaction oracle |
| Phase anchors | `docs/issues/<NNN>-<slug>/autopilot-prd.pin` / `autopilot-design.pin` (AL-2) |
| Audit trail | `docs/issues/<NNN>-<slug>/autopilot-log.jsonl` (one JSONL line per iteration, AL-4) |

**Output language: Japanese (fixed).** Structural tokens (PASS/FAIL, AL ids, oracle terms) are kept verbatim.

## Flow — two convergence phases around the design-approval gate

1. **Precondition.** The approved PRD exists at `docs/issues/<NNN>-*/prd.md`. Missing or unapproved → stop and route to `defining-requirements`.
2. **Design phase (autonomous).** Invoke the Workflow script below with `args = { issue: NNN, phase: 'design' }` — pass `args` as a JSON object（文字列化した JSON を渡さない, #256）. Converges `extracting-user-stories` then `writing-plan-and-tests`, anchored to the pinned PRD. No executable AT suite exists yet, so the AT / coverage gates are off and the oracle is reviewer-only.
3. **Design-approval gate (User gate).** Present the near-green `user-stories.md` / `plan.md` / `acceptance-tests.md` via **AskUserQuestion** and ask for approval. The full presentation contract — `Approve design?` header, `(Recommended) 承認 (ok)` first option, the three artifact send-backs, `multiSelect: false`, the harness-auto `Other`, the non-selection-UI `ok` fallback, and the approval/rejection semantics — lives in `docs/methodology/autopilot-design-gate.md` (#305); load it for this gate. The gate prompt text is:
   > `設計成果物（user-stories / plan / acceptance-tests）を承認しますか? 'ok' で ATDD（impl phase）へ進みます。修正点があればコメントしてください。`
   **Diff-in-body (mandatory, #275).** The gate message itself must carry the evidence, inline in BOTH the in-session message and the GitHub gate comment — complementing #267: deliverable bodies still travel as the Draft PR diff; the inline hunks are the decision evidence, not a replacement channel. On every re-presentation after fixes (re-presentation = the gate of a run re-invoked with `rejectionFindings`, #261; anything else is a first presentation), show the actual diff hunks of what changed (```diff blocks organized per finding, with the key lines called out — *key lines* = lines that directly implement an AC, change a public interface, or are quoted in a rejection finding). On first presentation, show each artifact's key decisions with file/line references — *key decision* = a choice that, if reversed, changes at least one AC or the plan's step structure; formatting choices and facts derivable from the Issue body (#254) do not qualify. Never present a summary-only gate that makes the user ask for the diff.
   Selection only changes presentation — the semantics are unchanged. Do not proceed without an explicit `ok`. Any non-`ok` response — a send-back option, an `Other` free-text comment, or partial approval like「A は ok / B は要修正」— rejects the **whole deliverable set**（部分承認は承認ではない）; never enter the impl phase on it (#261). On rejection: split the comment セクション単位 into findings（1 セクションの指摘 = 1 finding — never collapse multiple points into one）, each with `priority`（0 = blocker unless the human states a severity）and `evidence_ref` = that section's human comment verbatim, then re-invoke the Workflow with `args = { issue: NNN, phase: 'design', rejectionFindings: [...] }` (a JSON object, #256) so they reach iteration 1's generate verbatim. autopilot Gate ① (requirements approval) issues no requirements question of its own — it delegates to `defining-requirements` (壁打ち); there is no separate autopilot requirements-approval gate (AL-1 traceability, #305 finding #3).
4. **Impl phase (autonomous).** Invoke the script with `args = { issue: NNN, phase: 'impl' }` — pass `args` as a JSON object（文字列化した JSON を渡さない, #256）. It pins the design-gate-approved anchor and converges `running-atdd-cycle` under the deterministic AT gate (AL-3) and the AC→AT coverage gate (AL-2).
5. **Hand off.** The near-green Issue goes to the user merge gate (`merging-and-deploying`). Diff-in-body (#275) applies here too: the hand-off message includes the implementation diff inline (per-file stat = the `git diff --stat` summary, plus the key hunks — hunks containing key lines as defined in step 3), not just a green-status summary.

## Mechanism — one Workflow loop, invoked once per phase

Invoking this skill opts into the **Workflow tool**. For each step S of the current phase, loop `generate → review → fix`:

1. **generate** — run S's flow skill to produce or repair its artifact, anchored to this phase's immutable approved anchor.
2. **review** — run `reviewing-deliverables` (single-pass primitive, unchanged) → its structured verdict (`overall_correctness` + `findings[]`, each carrying `priority` and `evidence_ref`).
3. **deterministic AT gates** — impl phase only: (a) **red gate (#334)** `redObserved` from `check_red_evidence` exit code — AT failing BEFORE impl (red.jsonl), symmetric to AL-3; (b) **green gate (AL-3)** `atGreen` from test command exit code — AT passing AFTER impl. Both exit-code-derived; never LLM opinion. Both default false (fail-closed).
4. **AC→AT coverage gate (AL-2)** — impl phase only: a check **run in a context separate from the AT author** confirms the AT encode every approved AC; any uncovered AC is a P0. This is the external anchor that stops the loop from grading its own AT.
5. **satisfaction oracle (#334)** — `AND(redObserved, atGreen [AL-3], coverageOk [AL-2], overall_correctness == "correct", confirmed P0/P1 == 0)`. A finding with an absent / non-numeric `priority` is treated as **blocking** (fail-safe), and a confirmed P0/P1 blocks **regardless of `evidence_ref`** — AL-4 is fail-safe, never fail-open.
   - satisfied → advance to the next step.
   - not satisfied → feed the findings **verbatim** back into generate (fix) and re-loop.
6. **safety rails** (`lib/autopilot_convergence.sh`, AL-5) — record the iteration to the JSONL, then check the rails, including `check_log_integrity` against the orchestrator-tracked expected line count (#262: a deleted / rolled-back audit log silently resets sameness & stuck — fail-closed instead); a **non-zero `record_iteration`** (corrupt / empty fingerprint) is itself a halt. **Halt + escalate to a human** on any.

```js
export const meta = {
  name: 'autopilot',
  description: 'autopilot: loop the flow skills generate→review→fix until the satisfaction oracle holds, with safety rails',
  phases: [{ title: 'Generate' }, { title: 'Review' }, { title: 'AT-gate' }, { title: 'Coverage-gate' }, { title: 'Rails' }],
}

// Defensive args parse (#252/#256): the harness may deliver args as a JSON string; running with issue=undefined breaks AL-2 anchoring — fail closed.
const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
const NNN = A.issue
if (!Number.isInteger(NNN)) throw new Error('args.issue missing or non-integer — refusing to run with an unresolvable issue dir')
// Two-phase split (#249): 'design' ends at the human design-approval gate; 'impl' runs after it. No default (#256): stringified args left A.phase undefined and silently ran impl as design.
if (A.phase !== 'design' && A.phase !== 'impl') throw new Error('args.phase missing or invalid — refusing to default to design')
const PHASE = A.phase
const MODEL = PHASE === 'impl' ? 'sonnet' : undefined
// #261: gate rejection = NEW Workflow call; rejectionFindings carry human comments into iteration 1. Fail-closed.
if (A.rejectionFindings !== undefined) {
  if (!Array.isArray(A.rejectionFindings)) throw new Error('args.rejectionFindings must be an array')
  if (A.rejectionFindings.length === 0) throw new Error('args.rejectionFindings must not be empty — [] is truthy and .some() is vacuously false, so it would slip every guard and reach generate as a zero-finding re-presentation')
  if (A.rejectionFindings.some((f) => typeof f?.evidence_ref !== 'string' || f.evidence_ref === '')) throw new Error('every rejectionFindings item needs a non-empty evidence_ref (AL-4)')
  if (PHASE !== 'design') throw new Error('rejectionFindings is design-gate plumbing — refusing it outside the design phase')
}
const REJECTION_FINDINGS = A.rejectionFindings || null
// #288: impl-phase re-entry analogue of #261 rejectionFindings; seeds iteration 1 with unresolved halt findings.
if (A.implSeedFindings !== undefined) {
  if (!Array.isArray(A.implSeedFindings)) throw new Error('args.implSeedFindings must be an array')
  if (A.implSeedFindings.length === 0) throw new Error('args.implSeedFindings must not be empty — [] is truthy and .some() is vacuously false, so it would slip every guard and reach generate as a zero-finding re-presentation')
  if (A.implSeedFindings.some((f) => typeof f?.evidence_ref !== 'string' || f.evidence_ref === '')) throw new Error('every implSeedFindings item needs a non-empty evidence_ref (AL-4)')
  if (PHASE !== 'impl') throw new Error('implSeedFindings is impl-phase re-entry plumbing — refusing it outside the impl phase')
}
const IMPL_SEED_FINDINGS = A.implSeedFindings || null
const SEED_FINDINGS = PHASE === 'design' ? REJECTION_FINDINGS : IMPL_SEED_FINDINGS // phase-exclusive seeds → iteration 1
// #288: the audit log + pins are orchestrator-owned; the gen agent must never touch them in either direction (discarding uncommitted rows OR appending fake PASS rows both broke the log-integrity rail).
const GEN_GUARD = ' The audit log (autopilot-log.jsonl) and the *.pin anchors are orchestrator-owned: never read, append to, edit, delete, commit, or roll back them — and never git restore / checkout -- / stash uncommitted work you did not create. Do not change, commit, or add exclude/skip config for foreign files (files outside this Issue\'s scope that you did not create); if a gate fails due to such foreign files, do not fix them — escalate as COMPLETED_WITH_DEBT to a human.'
const STEPS = A.steps || (PHASE === 'design'
  ? ['extracting-user-stories', 'writing-plan-and-tests']
  : ['running-atdd-cycle'])
const MAX_ITERATIONS = A.maxIterations || {
  'extracting-user-stories': 4, 'writing-plan-and-tests': 4, 'running-atdd-cycle': 8,
}
// The step that produces an executable AT suite. For it (and only it) the deterministic AT gate (AL-3) and the AC→AT coverage gate (AL-2) run.
const AT_STEP = A.atStep || 'running-atdd-cycle'
const AT_COMMAND = A.atCommand || "the project's Acceptance Test command (e.g. `scripts/run-tests.sh --impact --base <base-ref>`)" // impact-scope for inner-loop speed; merge-gate enforces --all regardless
// Fail-closed preconditions. impl: the AT step must be looped, or the AT + coverage gates silently vanish (oracle degrades to LLM opinion). design: the AT step must NOT be looped — ATDD runs only after the design-approval gate (AL-1).
if (PHASE === 'impl' && !STEPS.includes(AT_STEP)) throw new Error(`AT_STEP "${AT_STEP}" not in STEPS — AT/coverage gates would be skipped`)
if (PHASE === 'design' && STEPS.includes(AT_STEP)) throw new Error(`design phase must not loop ${AT_STEP} — ATDD runs only after the design-approval gate`)
// The issue dir is slug-suffixed (docs/issues/<NNN>-<slug>/); the audit step resolves it by glob at write time — a bare-number dir would break AL-4.
const LOG_GLOB = `docs/issues/${NNN}-*/autopilot-log.jsonl`
// AL-2 anchor: never an artifact this phase's loop may edit. design: approved PRD. impl: prd.md + user-stories.md.
// acceptance-tests.md is NOT pinned (lifecycle markers move); the AC→AT coverage gate guards it.
const PIN_NAME = PHASE === 'design' ? 'autopilot-prd.pin' : 'autopilot-design.pin'
const ANCHOR_CAT = PHASE === 'design' ? 'cat <dir>/prd.md' : 'cat <dir>/prd.md <dir>/user-stories.md'

// Consumer schema. findings items REQUIRE priority + evidence_ref so the oracle can never read an undefined priority as "not blocking" (fail-open). atGreen is NOT taken from the reviewer here — it comes from the deterministic gate.
const VERDICT_SCHEMA = {
  type: 'object',
  required: ['verdict', 'overall_correctness'],
  properties: {
    verdict: { type: 'string' },               // PASS | FAIL
    overall_correctness: { type: 'string', enum: ['correct', 'incorrect'] },    // correct | incorrect
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

// Normalize an LLM-supplied priority; an absent / non-numeric value is treated as 0 (blocker) so a malformed finding can never slip through as "not blocking".
const priorityOf = (f) => {
  if (typeof f.priority === 'number') return f.priority
  const m = String(f.priority ?? '').match(/\d+/)
  return m ? Number(m[0]) : 0
}

// Review scope per phase × step (#252): without it the design-phase review flagged missing production code / executable AT as P0 (unconvergeable), and the US-step review drew findings against plan.md it had not yet produced.
const reviewScope = (step) => PHASE === 'impl'
  ? 'Scope: the impl deliverables (production code, executable AT, doc sync). Also flag as a P0 finding any committed change (git diff main...HEAD) to an out-of-scope path outside this Issue (e.g. pyproject.toml, CI config, other Issue sources).'
  : `Scope (design phase): ${step === 'extracting-user-stories'
    ? 'judge ONLY prd.md vs user-stories.md consistency; do NOT return findings on plan.md / acceptance-tests.md (later steps own them).'
    : 'judge the planning set (user-stories.md / plan.md / acceptance-tests.md).'} Production code and an executable AT suite do NOT exist yet BY DESIGN — their absence is NOT a finding.`

// FREEZE (AL-2) — pin this phase's human-approved anchor ONCE, before any
// iteration. On re-entry (design-gate rejection) the pin already exists: verify
// it still matches instead of failing the freeze. Refuse on mismatch / write failure.
const frozen = await agent(`Resolve the issue directory matching docs/issues/${NNN}-* and freeze this phase's immutable human-approved anchor (AL-2) via lib/autopilot_convergence.sh. If "<dir>/${PIN_NAME}" does not exist: \`${ANCHOR_CAT} | pin_anchor "<dir>/${PIN_NAME}"\` (pins once). If it already exists: \`cur="$(${ANCHOR_CAT} | fingerprint)"; check_pin "<dir>/${PIN_NAME}" "$cur"\` (the anchor must still match the frozen pin). Report pinned = (that command's exit code === 0). Also report logLines = the current non-empty line count of the audit log (${LOG_GLOB}; \`grep -c . <log>\`), or 0 if the file does not exist.`, { label: 'freeze:anchor', phase: 'Generate', schema: { type: 'object', required: ['pinned', 'logLines'], properties: { pinned: { type: 'boolean' }, logLines: { type: 'integer' } } } })
if (frozen == null) return { status: 'COMPLETED_WITH_DEBT', step: 'freeze', reason: 'freeze-error' }
if (frozen.pinned !== true) return { status: 'COMPLETED_WITH_DEBT', step: 'freeze', reason: 'anchor-pin-failed' }
// #262 baseline absorption: lines already in the log (re-entry after a design-gate
// rejection, or an earlier phase) are the truth. From here the expected line count
// lives in JS process memory — deleting the log cannot delete the expectation.
let recorded = frozen.logLines

for (const step of STEPS) {
  const max = MAX_ITERATIONS[step] || 4
  const atRequired = step === AT_STEP
  let it = 0
  // #252: carry the previous verdict's findings into the next generate call —
  // a fresh-context gen agent cannot "fix them verbatim" without their text.
  // #261/#288: the phase seed (design rejectionFindings / impl re-entry implSeedFindings) seeds
  // iteration 1; absent priority → 0 = blocker (fail-safe).
  let prevFindings = SEED_FINDINGS ? SEED_FINDINGS.map((f) => ({ ...f, priority: priorityOf(f) })) : null
  for (;;) {
    it++
    // 1. generate / fix — run the EXISTING flow skill (not rewritten). From
    //    iteration 2 the prior findings are embedded verbatim (JSON).
    await agent(prevFindings
      ? `Run the ${step} flow skill for Issue #${NNN}, anchored to this phase's immutable approved anchor.${GEN_GUARD} Fix these previous review findings verbatim:\n${JSON.stringify(prevFindings)}`
      : `Run the ${step} flow skill for Issue #${NNN}, anchored to this phase's immutable approved anchor.${GEN_GUARD} If a prior review left findings, fix them verbatim.`, { label: `gen:${step}`, phase: 'Generate', model: MODEL })
    // 2. review — single-pass primitive, structured verdict, phase×step scope
    const verdict = await agent(`Run reviewing-deliverables for Issue #${NNN} (phase: ${PHASE}, step: ${step}). ${reviewScope(step)} Return its structured verdict (overall_correctness + findings[], each with priority and evidence_ref).`, { label: `review:${step}`, phase: 'Review', schema: VERDICT_SCHEMA, model: MODEL })
    // 3. DETERMINISTIC AT gate (AL-3) — atGreen is the test command's EXIT CODE,
    //    never an LLM opinion. Default false when AT is required and not run.
    let atGreen = !atRequired
    if (atRequired) {
      const at = await agent(`Run the executable Acceptance Test suite for Issue #${NNN} (${AT_COMMAND}). Actually execute it; report ONLY the command's integer exit code and green = (exit code === 0). Do NOT judge whether tests "would" pass.`, { label: `at-gate:${step}`, phase: 'AT-gate', schema: { type: 'object', required: ['exitCode', 'green'], properties: { exitCode: { type: 'integer' }, green: { type: 'boolean' }, log: { type: 'string' } } }, model: MODEL })
      atGreen = at != null && at.exitCode === 0 && at.green === true
    }
    // 4. AC→AT coverage gate (AL-2) — separate context from the AT author.
    let coverageOk = !atRequired
    let uncovered = []  // #272: ループスコープで宣言 — audit payload から参照可能にする
    if (atRequired) {
      const cov = await agent(`In a context SEPARATE from the AT author, verify the executable Acceptance Tests for Issue #${NNN} encode EVERY approved AC in the immutable design anchor (docs/issues/${NNN}-*/acceptance-tests.md + the design-gate-approved AC). List uncovered AC; each is a P0.`, { label: `coverage:${step}`, phase: 'Coverage-gate', schema: { type: 'object', required: ['allCovered', 'uncovered'], properties: { allCovered: { type: 'boolean' }, uncovered: { type: 'array', items: { type: 'string' } } } }, model: MODEL })
      uncovered = cov?.uncovered || []
      coverageOk = cov != null && cov.allCovered === true && uncovered.length === 0
    }
    const blocking = (verdict != null ? verdict.findings || [] : []).filter((f) => priorityOf(f) <= 1)
    // #334 red gate (impl only) — symmetric to AL-3 green gate: AT failing BEFORE impl (exit code, red.jsonl). Default false.
    // #355 (F8): read SHA values from the red.jsonl record (recorded at C2 Confirm RED) — no git log archaeology.
    let redObserved = !atRequired
    if (atRequired) {
      const red = await agent(`Via lib/autopilot_convergence.sh, check red evidence for Issue #${NNN}. Steps: (1) resolve docs/issues/${NNN}-*/red.jsonl — read SHAs from the JSONL record (do NOT reconstruct via git log); (2) extract test_sha from the "commit" field and impl_sha from the "impl_sha" field of the most recent record; (3) \`source lib/autopilot_convergence.sh; check_red_evidence "$test_sha" "$impl_sha" "<red-jsonl>"; echo exit:$?\`; (4) report exitCode and redObserved=(exitCode===0). If the record has no impl_sha field, report redObserved=false (fail-closed — do not substitute git rev-parse HEAD).`, { label: `red-gate:${step}`, phase: 'AT-gate', schema: { type: 'object', required: ['exitCode', 'redObserved'], properties: { exitCode: { type: 'integer' }, redObserved: { type: 'boolean' } } }, model: MODEL })
      redObserved = red != null && red.exitCode === 0 && red.redObserved === true
    }
    // 5. satisfaction oracle (#334) — AND(redObserved, atGreen [AL-3], coverageOk [AL-2], overall_correctness, P0/P1==0). Fail-safe.
    const converged = redObserved && atGreen && coverageOk && verdict != null && verdict.overall_correctness === 'correct' && blocking.length === 0
    // #355 (F1/F2): binary halt classification. "demonstrably-done" = review correct + tests green + zero blocking
    // findings but gate mechanism cannot self-verify (redObserved=false). Early escalation as gate-unverifiable —
    // do NOT exhaust MAX_ITERATIONS on a mechanism failure vs an incomplete-deliverable failure.
    const demonstrablyDone = verdict != null && verdict.overall_correctness === 'correct' && blocking.length === 0 && atGreen && coverageOk
    const gateUnverifiable = !converged && demonstrablyDone && !redObserved && atRequired
    // 6. AUDIT FIRST (AL-4) — record EVERY iteration before deciding (JSONL = external truth).
    //    record_iteration full sig: <jsonl> <it> <step> <verdict> <fp>. non-zero = halt (#252 verbatim payload, #272 oracle state in fp).
    const rec = await agent(`Resolve the issue directory matching docs/issues/${NNN}-* (it exists) and append one audit line to its autopilot-log.jsonl (${LOG_GLOB}) via lib/autopilot_convergence.sh. The blocking-findings payload to fingerprint is the exact text between the two marker lines below (hash the payload only, never the markers):
BEGIN-PAYLOAD
${JSON.stringify({ redObserved, atGreen, coverageOk, uncovered, blocking })}
END-PAYLOAD
Steps: (1) write the payload byte-for-byte to a temp file using a quoted heredoc (\`cat > "$tmp" <<'PAYLOAD_EOF'\` … \`PAYLOAD_EOF\` — quoted so nothing expands); (2) \`fp="$(fingerprint < "$tmp")"\`; (3) \`record_iteration "<resolved-log-path>" ${it} ${step} ${converged ? 'PASS' : 'FAIL'} "$fp"\`; (4) #288: if record_iteration succeeded, IMMEDIATELY commit ONLY the audit log so a later working-tree rollback by the next gen agent cannot delete this row — \`git add "<resolved-log-path>" && git commit -m "chore(autopilot): audit ${step} iteration ${it} (#${NNN})"\` (stage the log file alone, nothing else). Report recordOk = (record_iteration exit code === 0).`, { label: `audit:${step}`, phase: 'Rails', schema: { type: 'object', required: ['recordOk'], properties: { recordOk: { type: 'boolean' } } }, model: MODEL })
    if (rec == null || rec.recordOk !== true) return { status: 'COMPLETED_WITH_DEBT', step, reason: 'record-error', verdict }
    recorded++ // #262: a successful record_iteration = exactly one more log line, mirrored in memory
    if (converged) { log(`${step}: converged at iteration ${it}`); break }
    // #355 (F1/F2): gate-unverifiable early escalation — mechanism failure, not deliverable failure.
    if (gateUnverifiable) {
      const guvFindings = (verdict?.findings || []).filter((f) => priorityOf(f) <= 1).map((f) => ({ priority: f.priority, evidence_ref: f.evidence_ref }))
      await agent(`Resolve docs/issues/${NNN}-* and its audit log (${LOG_GLOB}). Via lib/autopilot_convergence.sh: \`record_halt "<log>" ${step} gate-unverifiable '${JSON.stringify(guvFindings)}'\`. Then commit ONLY the log: \`git add "<log>" && git commit -m "chore(autopilot): halt record ${step} gate-unverifiable (#${NNN})"\`. Report haltRecorded = (record_halt exit code === 0).${GEN_GUARD}`, { label: `audit-halt:${step}`, phase: 'Rails', schema: { type: 'object', required: ['haltRecorded'], properties: { haltRecorded: { type: 'boolean' } } }, model: MODEL })
      return { status: 'COMPLETED_WITH_DEBT', step, reason: 'gate-unverifiable', verdict }
    }
    // 7. safety rails (AL-5) — each check returns its raw EXIT CODE; HALT is JS-computed (not LLM-summarized).
    const r = await agent(`Resolve the issue directory matching docs/issues/${NNN}-* (it exists) and its real audit log (${LOG_GLOB}); run every check against those ACTUAL resolved paths (substitute them for "<dir>" / "<log>" below). #287: NEVER fabricate synthetic fixtures, sample FAIL rows, or /tmp copies of the log / anchor — a check run against invented data reports a false halt; operate only on the real audit log and the pinned anchor. Via lib/autopilot_convergence.sh, run all five and report each one's integer exit code: (a) anchor drift — \`cur="$(${ANCHOR_CAT} | fingerprint)"; check_pin "<dir>/${PIN_NAME}" "$cur"\` (AL-2: the approved anchor must not have changed since the freeze); (b) check_max_iterations ${it} ${max}; (c) check_sameness "<log>" "${step}" (#272: step スコープ化で偽 halt を防ぐ; #277: FAIL 行のみ比較 — PASS 行は比較母集団から除外される); (d) check_stuck "<log>" 3 "${step}" (#272: 同上; #277: FAIL 行のみ比較); (e) check_log_integrity "<log>" ${recorded} (#262: the log must hold EXACTLY the lines the orchestrator recorded — a deleted / rolled-back log silently resets sameness & stuck).`, { label: `rails:${step}`, phase: 'Rails', schema: { type: 'object', required: ['acDriftExit', 'maxIterExit', 'samenessExit', 'stuckExit', 'logIntegrityExit'], properties: { acDriftExit: { type: 'integer' }, maxIterExit: { type: 'integer' }, samenessExit: { type: 'integer' }, stuckExit: { type: 'integer' }, logIntegrityExit: { type: 'integer' } } }, model: MODEL })
    if (r == null) return { status: 'COMPLETED_WITH_DEBT', step, reason: 'rails-error', verdict }
    // log-integrity outranks sameness/stuck (both read FROM the log). `recorded` is NOT incremented for the HALT line.
    const halt = r.acDriftExit !== 0 ? 'ac-drift' : r.logIntegrityExit !== 0 ? 'log-integrity' : r.maxIterExit !== 0 ? 'MAX_ITERATIONS' : r.samenessExit !== 0 ? 'sameness-detector' : r.stuckExit !== 0 ? 'stuck' : 'none'
    if (halt !== 'none') {
      const haltFindings = [...(verdict?.findings || []).filter((f) => priorityOf(f) <= 1), ...uncovered.map((ac) => ({ priority: 0, evidence_ref: ac }))].map((f) => ({ priority: f.priority, evidence_ref: f.evidence_ref }))
      const haltResult = await agent(`Resolve the issue directory matching docs/issues/${NNN}-* and its audit log (${LOG_GLOB}). Via lib/autopilot_convergence.sh, append one terminating HALT record: \`record_halt "<resolved-log-path>" ${step} ${halt} '${JSON.stringify(haltFindings)}'\`. Then commit ONLY the log: \`git add "<resolved-log-path>" && git commit -m "chore(autopilot): halt record ${step} ${halt} (#${NNN})"\`. Report haltRecorded = (record_halt exit code === 0).${GEN_GUARD}`, { label: `audit-halt:${step}`, phase: 'Rails', schema: { type: 'object', required: ['haltRecorded'], properties: { haltRecorded: { type: 'boolean' } } }, model: MODEL })
      const haltRecorded = haltResult?.haltRecorded ?? false // best-effort; COMPLETED_WITH_DEBT proceeds regardless
      return { status: 'COMPLETED_WITH_DEBT', step, reason: halt, verdict }
    }
    prevFindings = verdict?.findings?.length ? verdict.findings : null
  }
}
return { status: 'CONVERGED', phase: PHASE, steps: STEPS }
```

**bugfix oracle (#308):** on the `fixing-bugs` route the oracle is specialized — see `docs/methodology/autopilot-iron-law.md` (AL-3 bugfix specialization): `回帰テスト green ＋ 既存回帰なし ＋ 失敗再現テスト 赤→緑`, `AC→AT coverage` specialized to failing-repro-test coverage, middle gate = **cause-agreement**, merge = User gate (AL-1); wiring detail in that doc, referenced only. **flaky oracle (#322):** on the `fixing-flaky-tests` route the oracle is `N 回連続 green（決定化）＋ 既存回帰なし ＋ 反復 failing アンカー 赤→N 回連続緑`; single-run green is not convergence; middle gate = **cause-agreement** (承認対象 = 非決定性分類＋失敗率); route determination via `docs/methodology/route-eligibility.md` (SoT); wiring detail in `docs/methodology/autopilot-iron-law.md` (AL-3 flaky specialization), referenced only.

The rails (`fingerprint` / `record_iteration` / `record_halt` / `check_sameness` / `check_stuck` / `check_max_iterations` / `check_log_integrity` / `pin_anchor` / `check_pin`) live in `lib/autopilot_convergence.sh` as the single, BATS-verified source — the workflow calls them rather than re-deriving the logic in JS. A non-`none` `halt` means **escalate to a human** with `COMPLETED_WITH_DEBT` recorded; autopilot never silently loops forever or fakes green. On impl-phase re-entry after such a halt, carry the unresolved findings (the halt `verdict.findings` plus any coverage-gate uncovered AC, each with a non-empty `evidence_ref`) into the new Workflow call as `args.implSeedFindings` (#288) — the impl analogue of design's `rejectionFindings`; without it iteration 1 restarts blind (`prevFindings = null`) and review / coverage re-derive the same rejection.

## Model assignment (#259)

- **impl phase subagents (gen / review / at-gate / coverage / audit / rails / audit-halt) default to Sonnet** (#311/#299: each agent() opts carries `model`) — bench #259 showed equal functional quality at ~1/4 the cost. **Design-heavy Issues** (architecture judgment / trade-offs) start on the **session model** instead.
- **Escalation (one-way per Issue):** a Sonnet cycle ending `COMPLETED_WITH_DEBT` via a convergence-failure halt (`MAX_ITERATIONS` / `sameness-detector` / `stuck`) promotes that step's impl / review subagents to the session model from the next convergence cycle (after human intervention); never demote back within the same Issue. `ac-drift` / `record-error` are anchor / audit-integrity halts, not model-quality signals — they do not escalate.
- **Out of scope:** the design phase (`extracting-user-stories` / `writing-plan-and-tests`) and this orchestrator stay on the session model (bench: design-judgment consistency Fable 20/20). Policy details: `agents/README.md`.

## Responsibility Boundary

See `docs/methodology/autopilot-overview.md` — role map (autopilot / flow-skills / reviewing-deliverables / human / skill-gate) and ownership table.

## Integration

- **Upstream:** `defining-requirements` (the approved PRD — the first User gate)
- **Mid-flow:** the design-approval gate (the human approves the converged design deliverables before ATDD)
- **Downstream:** `merging-and-deploying` (the User merge gate, on a near-green Issue)
