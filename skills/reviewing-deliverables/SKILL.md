---
name: reviewing-deliverables
description: "Use when implementation is complete and deliverables (code, AT, docs) need structured review before merge."
---

# Reviewing Deliverables

Step 5 of the atdd-kit v1.0 flow. Review the deliverables produced by Steps 1–4 (PRD / User Stories / Plan / Code / Acceptance Tests) by running a **Workflow** — Claude Code's deterministic JS orchestration — that **generates the reviewer panel dynamically from the deliverable content** and runs it **in parallel across multiple adversarial verification rounds**. The panel covers functional and non-functional concerns and multiple stances (advocate / skeptic), scaled to what the change actually touches.

**Scope ends at the review verdict.** Merging the PR, deploying, and post-deploy regression are owned by `merging-and-deploying` (Step 6). This skill judges quality; it does not merge or deploy.

## Why a parallel, dynamic Workflow (and not a fixed serial roster)

The earlier mechanism ran a fixed roster of reviewer subagents **serially**. That serial rule existed only to avoid subagent **cross-talk** in the Agent-tool spawning pattern (#216 PRD Open Question #1, which explicitly deferred parallelization to a later Issue). The **Workflow tool dissolves that constraint**: every `agent()` runs in an isolated context, and `parallel()` / `pipeline()` collect `schema`-validated outputs deterministically, so reviewers cannot bleed into each other. #234 is that deferred Issue: the panel is now **dynamic** (derived from the change) instead of a fixed list, and **parallel** instead of serial.

## Trigger

- **Explicit:** `/atdd-kit:reviewing-deliverables <issue-number>`
- **Keyword-detected (confirm first):** on review intent ("レビュー", "review", "成果物チェック"), ask `Run reviewing-deliverables on <issue>? Y/n` before starting.

## Input

- Issue number (argument, or recognized in a user message).
- The deliverables, read directly: `docs/issues/<NNN>/{prd,user-stories,plan,acceptance-tests}.md`, the production code diff (`git diff <base>...HEAD`, base = `main`), and the executable Acceptance Tests under `tests/acceptance/`.

No Context Block.

## Output

| Artifact | Form |
|----------|------|
| Review verdict | One **PASS / FAIL** from the Aggregate phase, plus the per-lens review notes from the generated panel. |

**Output language: Japanese (fixed).** Review notes and the verdict rationale are written in Japanese; structural tokens (`PASS` / `FAIL`, severity ids) are kept verbatim.

## Review mechanism — a dynamic parallel Workflow

Invoking this skill is the opt-in to call the **Workflow tool**. Run the script below via the Workflow tool with `args: { issue: <NNN>, base: "main" }`. The dynamism lives **inside** the workflow — Scout inspects the change, Generate derives the panel — so the one script adapts to any deliverable; do not hand-edit the roster.

Five phases:

1. **Scout** — one agent reads the deliverables and reports their types, languages, change size, and every **risk surface** the change touches (auth, input/IO, network, concurrency, data/migration, UI/UX, performance-sensitive paths, error handling).
2. **Generate** — one agent turns the scout report into a **dynamic** review panel. It ALWAYS includes functional-correctness, clean-code, testability, **documentation**, and a positive **advocate** + a negative **skeptic**; it ADDS a non-functional lens (security, performance / load, usability, …) **only for each risk surface the scout actually found**. Panel size and personas therefore scale with the change. The **documentation** lens is always present because every change can drift its docs: it judges (a) **accuracy** — prose (README / CHANGELOG / `docs/`) matches what actually changed; (b) **consistency** — cross-doc coherence (e.g. `skills/README.md` lists every skill); and (c) **follow-through / sync** — the DEVELOPMENT.md invariants verified against the diff: if files under a top-level dir (`skills/`, `scripts/`, `tests/`, `hooks/`, `rules/`, `commands/`, `templates/`, `agents/`) changed, that dir's `README.md` is updated in the same PR, and a feature change carries a `CHANGELOG.md` entry plus a `.claude-plugin/plugin.json` version bump.
3. **Review (parallel)** — each generated lens reviews its target deliverable concurrently, returning findings with severity and location.
4. **Verify (multi-round, adversarial)** — each finding is independently challenged by several skeptics across diverse angles; a finding survives only on **majority** confirmation. This suppresses false positives.
5. **Aggregate** — one agent consolidates the surviving findings and per-lens notes into a single **PASS / FAIL** verdict, written in Japanese.

```js
export const meta = {
  name: 'review-deliverables',
  description: 'Scout the deliverables, generate a reviewer panel dynamically, review in parallel, verify findings adversarially, aggregate to PASS/FAIL',
  phases: [
    { title: 'Scout' },
    { title: 'Generate' },
    { title: 'Review' },
    { title: 'Verify' },
    { title: 'Aggregate' },
  ],
}

const NNN = args.issue
const BASE = args.base || 'main'

// --- Phase 1: Scout -------------------------------------------------------
phase('Scout')
const SCOUT_SCHEMA = {
  type: 'object',
  required: ['deliverables', 'languages', 'riskSurfaces', 'size'],
  properties: {
    deliverables: { type: 'array', items: { type: 'string' } }, // which of prd/us/plan/code/at exist
    languages: { type: 'array', items: { type: 'string' } },
    riskSurfaces: { type: 'array', items: { type: 'string' } }, // auth, io, network, concurrency, data-migration, ui, perf, error-handling
    size: { type: 'string' },                                   // small | medium | large
    notes: { type: 'string' },
  },
}
const scout = await agent(
  `Analyze the deliverables for Issue #${NNN}. Read docs/issues/${NNN}/prd.md, user-stories.md, plan.md, acceptance-tests.md (skip any that are missing), the production diff (git diff ${BASE}...HEAD), and tests/acceptance/. Report which deliverables exist, the languages, the change size, and EVERY risk surface the change touches (auth, input/IO, network, concurrency, data/migration, UI/UX, performance-sensitive paths, error handling). Be specific and conservative — only list a surface the change actually touches.`,
  { phase: 'Scout', schema: SCOUT_SCHEMA }
)

// --- Phase 2: Generate the reviewer panel dynamically ---------------------
phase('Generate')
const PANEL_SCHEMA = {
  type: 'object',
  required: ['lenses'],
  properties: {
    lenses: {
      type: 'array',
      items: {
        type: 'object',
        required: ['key', 'persona', 'target', 'focus'],
        properties: {
          key: { type: 'string' },     // security, performance, usability, clean-code, testability, advocate, skeptic, ...
          persona: { type: 'string' }, // the reviewer's voice and stance
          target: { type: 'string' },  // which deliverable to review
          focus: { type: 'string' },   // what to look for
        },
      },
    },
  },
}
const panel = await agent(
  `Given this scout report:\n${JSON.stringify(scout)}\n\nDesign the review panel for this change. ALWAYS include these lenses: functional-correctness, clean-code, testability, documentation, a positive advocate (argues the change is sound), and a negative skeptic (hunts for what breaks). The documentation lens is mandatory on EVERY change — its focus must cover: (a) accuracy — README / CHANGELOG / docs/ prose matches what actually changed; (b) consistency — cross-doc coherence (e.g. skills/README.md lists every skill, tests/README.md lists the test files); and (c) follow-through / sync — verify the DEVELOPMENT.md invariants against the diff: when files under a top-level dir (skills/, scripts/, tests/, hooks/, rules/, commands/, templates/, agents/) changed, that dir's README.md is updated in the SAME change, and a feature change carries a CHANGELOG.md entry plus a .claude-plugin/plugin.json version bump. A missing doc update that DEVELOPMENT.md requires is a real finding (severity major). ADD one dedicated lens for EACH risk surface the scout found — e.g. security when auth/input/network is touched, performance/load when perf-sensitive paths are touched, usability when UI/UX is touched. For each lens give: a key, a distinct reviewer persona, the target deliverable, and a sharp focus. Scale the panel to the change; do NOT invent lenses for surfaces that are absent.`,
  { phase: 'Generate', schema: PANEL_SCHEMA }
)
const lenses = panel.lenses
log(`Generated ${lenses.length} reviewers: ${lenses.map(l => l.key).join(', ')}`)

// --- Phases 3+4: Review in parallel, then verify each finding adversarially
const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'severity', 'location', 'detail'],
        properties: {
          title: { type: 'string' },
          severity: { type: 'string' }, // blocker | major | minor | nit
          location: { type: 'string' },
          detail: { type: 'string' },
        },
      },
    },
  },
}
const VERDICT_SCHEMA = {
  type: 'object',
  required: ['real', 'reason'],
  properties: { real: { type: 'boolean' }, reason: { type: 'string' } },
}
const ANGLES = ['correctness', 'severity', 'reproducibility'] // 3 adversarial rounds per finding

const reviewed = await pipeline(
  lenses,
  (lens) =>
    agent(
      `You are "${lens.persona}". Review ${lens.target} for Issue #${NNN} through the ${lens.key} lens. Focus: ${lens.focus}. Report concrete findings, each with a severity (blocker|major|minor|nit) and a location. If you find nothing, return an empty findings array — do not invent issues.`,
      { label: `review:${lens.key}`, phase: 'Review', schema: FINDINGS_SCHEMA }
    ),
  (review, lens) =>
    parallel(
      review.findings.map((f) => () =>
        parallel(
          ANGLES.map((angle) => () =>
            agent(
              `Adversarially challenge this ${lens.key} finding via the ${angle} angle — try to refute it. Default to real=false if uncertain.\nFinding: ${JSON.stringify(f)}`,
              { label: `verify:${lens.key}`, phase: 'Verify', schema: VERDICT_SCHEMA }
            )
          )
        ).then((votes) => {
          const v = votes.filter(Boolean)
          const confirmed = v.filter((x) => x.real).length > v.length / 2
          return { ...f, lens: lens.key, confirmed, votes: v }
        })
      )
    )
)
const surviving = reviewed.flat().filter(Boolean).filter((f) => f.confirmed)

// --- Phase 5: Aggregate to one PASS/FAIL ----------------------------------
phase('Aggregate')
const AGG_SCHEMA = {
  type: 'object',
  required: ['verdict', 'summary', 'byLens'],
  properties: {
    verdict: { type: 'string' }, // PASS | FAIL
    summary: { type: 'string' }, // Japanese
    byLens: { type: 'array', items: { type: 'object' } },
  },
}
return await agent(
  `Aggregate these verified findings into one verdict for Issue #${NNN}. Rule: FAIL if any surviving finding is severity "blocker" or "major"; otherwise PASS. Write the summary and per-lens notes in JAPANESE; keep PASS/FAIL and severity ids verbatim.\nSurviving findings: ${JSON.stringify(surviving)}\nReviewers run: ${JSON.stringify(lenses.map((l) => l.key))}`,
  { phase: 'Aggregate', schema: AGG_SCHEMA }
)
```

**Runtime behavior is verified by the Acceptance Tests, not by manual checking.** A green `tests/acceptance/` suite (from Step 4) is the evidence of correct behavior. This skill does **not** require manual click-through or a preview launch — manual verification is not mandatory (PRD Non-Goal).

## Flow

1. Confirm the Step 1–4 deliverables exist. If a required artifact is missing, instruct the user to complete the corresponding step and stop.
2. Run the Workflow (Scout → Generate → Review → Verify → Aggregate).
3. Present the PASS / FAIL verdict and the per-lens notes in one message. On FAIL, name the failing lenses and surviving findings so Step 4 can address them; on PASS, the Issue is ready for `merging-and-deploying`.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Review verdict (PASS / FAIL) over PRD / US / Plan / Code / AT | **reviewing-deliverables** (this skill) |
| Plan + AT spec → green AT + production code | running-atdd-cycle (Step 4) |
| Merge + deploy + post-deploy AT regression | merging-and-deploying (Step 6) |
| Runtime behavior verification | the Acceptance Tests (`tests/acceptance/`, green at Step 4) |
| Parallel-session conflict, `in-progress` label management | skill-gate |

This skill **does not** add or remove the `in-progress` label — that is skill-gate's responsibility. It **does not** merge, deploy, or write code — it only reviews.

## Integration

- **Upstream:** `running-atdd-cycle` (its green Acceptance Tests and production code are the primary review targets)
- **Downstream:** `merging-and-deploying` (proceeds only on a PASS verdict)
