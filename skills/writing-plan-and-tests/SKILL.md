---
name: writing-plan-and-tests
description: "Use when User Stories are approved and you need to create an implementation plan with draft Acceptance Tests."
---

# Writing Plan and Tests

Step 3 of the atdd-kit v1.0 flow. Take an Issue number, read its approved User Stories, and produce an implementation Plan plus a draft Acceptance Test spec: `docs/issues/<NNN>/plan.md` (from `templates/docs/issues/plan.md`) and `docs/issues/<NNN>/acceptance-tests.md` (from `templates/docs/issues/acceptance-tests.md`). A `docs/issues/<NNN>/design-doc.md` is produced **only when** the work involves a real trade-off or competing alternatives.

**Scope ends at the Plan + AT spec.** Writing executable Acceptance Test files (`tests/acceptance/AT-*`) and the ATDD double loop are owned by `running-atdd-cycle` (Step 4, #191). This skill produces planning artifacts, not test code.

## Trigger

- **Explicit:** `/atdd-kit:writing-plan-and-tests <issue-number>`
- **Keyword-detected (confirm before invoking):** When user messages mention plan / acceptance-test authoring intent (e.g. "Plan", "受け入れテスト方針", "AT 設計"), ask `Run writing-plan-and-tests skill on <issue>? Y/n` before starting. Auto-invocation without confirmation is forbidden by the v1.0 Step B progression rule (#179).

## Input

- Issue number (command-line argument or recognized in a user message)
- User Stories file at `docs/issues/<NNN>/user-stories.md` read directly. If missing, instruct the user to run `extracting-user-stories` first and stop.

No other inputs. No Context Block. No resume of existing `docs/issues/<NNN>/plan.md`.

## Output

| Artifact | Path | Condition |
|----------|------|-----------|
| Plan | `docs/issues/<NNN>/plan.md` (copied from `templates/docs/issues/plan.md`, filled in) | always |
| Acceptance Test spec | `docs/issues/<NNN>/acceptance-tests.md` (copied from `templates/docs/issues/acceptance-tests.md`, filled in) | always |
| Design doc | `docs/issues/<NNN>/design-doc.md` | **optional** — only when a non-trivial trade-off or competing alternatives exist (Ubl 2020). Most Issues need none. A deep standalone design doc is owned by `writing-design-doc` (Step 8, on-demand). |

**Output language: Japanese (fixed).** Structural markers — Connextra phrases, the lifecycle tokens `[planned] [draft] [green] [regression]`, and `verify:` — are kept verbatim for recognition; body content (task descriptions, Given/When/Then, rationale) is written in Japanese.

No Issue comment, no `skill-status` fenced block.

## Flow

1. Read the User Stories at `docs/issues/<NNN>/user-stories.md`.
2. **Build the Plan.** Decompose each Story into **2-5 minute grained tasks** (single-operation steps, superpowers writing-plans style). Pair **every** task with a `verify:` line stating how its completion is checked. Group tasks under the template's `## Implementation` / `## Testing` / `## Finishing` sections.
3. **Build the Acceptance Test spec.** For each User Story / AC, write one AT entry with a lifecycle state marker, starting at `[planned]`. Express each as Given / When / Then. Encode the full lifecycle `planned → draft → green → regression` so test state stays traceable: `[planned]` (designed, not implemented) → `[draft]` (implemented, not yet passing) → `[green]` (passing) → `[regression]` (kept under continuous watch). Step 4 advances these markers; this skill only authors them at `[planned]`.
4. **Decide on a design doc.** If — and only if — the plan rests on a non-trivial trade-off or chooses among competing alternatives, write `docs/issues/<NNN>/design-doc.md` capturing the decision, the alternatives considered, and the trade-offs. Otherwise omit it; a design doc is never mandatory.
5. **Present** the Plan + AT spec (and the design doc, if any) in **one message** for visibility.
6. **Write artifacts.** `cp templates/docs/issues/plan.md docs/issues/<NNN>/plan.md` and `cp templates/docs/issues/acceptance-tests.md docs/issues/<NNN>/acceptance-tests.md`, then fill each in place. Per `workflow-overrides.md`, this skill does **not** hold a user-approval gate — technical review (R1-R6) is deferred to `reviewing-deliverables` (Step 5); the author retains the right to request revisions.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| User Stories → Plan + AT spec | **writing-plan-and-tests** (this skill) |
| Issue → PRD | defining-requirements (Step 1, #188) |
| PRD → User Stories | extracting-user-stories (Step 2, #189) |
| Executable AT files + ATDD double loop | running-atdd-cycle (Step 4, #191) |
| PRD / US / Plan / Code / AT review | reviewing-deliverables (Step 5, #192) |
| Deep standalone design doc (on-demand) | writing-design-doc (Step 8, #195) |
| Parallel-session conflict, `in-progress` label management | skill-gate (#197) |

This skill **does not** spawn reviewer subagents — Plan and AT review happens at Step 5. This skill **does not** add or remove the `in-progress` label — that is skill-gate's responsibility. This skill **does not** write executable test code — that is Step 4.

## Integration

- **Upstream:** `extracting-user-stories` (consumes its `docs/issues/<NNN>/user-stories.md`)
- **Downstream:** `running-atdd-cycle` (consumes `docs/issues/<NNN>/plan.md` and `docs/issues/<NNN>/acceptance-tests.md`)
