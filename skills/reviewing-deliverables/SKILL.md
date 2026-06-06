---
name: reviewing-deliverables
description: "Use when implementation is complete and deliverables (code, AT, docs) need structured review before merge."
---

# Reviewing Deliverables

Step 5 of the atdd-kit v1.0 flow. Take an Issue number, and review every deliverable produced by Steps 1–4 (PRD / User Stories / Plan / Code / Acceptance Tests) by invoking six specialist subagents **serially**. The five specialists check **47 structural criteria total**; the sixth aggregates their verdicts into one PASS / FAIL determination.

**Scope ends at the review verdict.** Merging the PR, deploying, and running post-deploy regression are owned by `merging-and-deploying` (Step 6, #193). This skill judges quality; it does not merge or deploy.

## Trigger

- **Explicit:** `/atdd-kit:reviewing-deliverables <issue-number>`
- **Keyword-detected (confirm before invoking):** When user messages mention review intent (e.g. "レビュー", "review", "成果物チェック"), ask `Run reviewing-deliverables skill on <issue>? Y/n` before starting. Auto-invocation without confirmation is forbidden by the v1.0 Step B progression rule (#179).

## Input

- Issue number (command-line argument or recognized in a user message)
- The Step 1–4 deliverables, read directly: `docs/issues/<NNN>/prd.md`, `docs/issues/<NNN>/user-stories.md`, `docs/issues/<NNN>/plan.md`, `docs/issues/<NNN>/acceptance-tests.md`, the production code diff, and the executable Acceptance Tests under `tests/acceptance/`.

No other inputs. No Context Block.

## Output

| Artifact | Form |
|----------|------|
| Review verdict | A single **PASS / FAIL** determination from `final-reviewer`, plus the per-deliverable review notes from each specialist |

**Output language: Japanese (fixed).** Review notes and the verdict rationale are written in Japanese; structural tokens (`PASS` / `FAIL`, criterion ids) are kept verbatim.

## Review mechanism — six subagents, run serially

Invoke the six reviewer subagents **one at a time (serial)**, never in parallel. Serial execution keeps each subagent's context isolated and avoids cross-talk between reviewers (#216 PRD Open Question #1).

| Order | Subagent | Reviews | Criteria |
|-------|----------|---------|----------|
| 1 | `prd-reviewer` | `docs/issues/<NNN>/prd.md` | 10 |
| 2 | `us-reviewer` | `docs/issues/<NNN>/user-stories.md` | 7 |
| 3 | `plan-reviewer` | `docs/issues/<NNN>/plan.md` | 10 |
| 4 | `code-reviewer` | production code diff | 10 |
| 5 | `at-reviewer` | `docs/issues/<NNN>/acceptance-tests.md` + `tests/acceptance/` | 10 |
| 6 | `final-reviewer` | aggregates verdicts 1–5 | — (47 total) |

The five specialists cover **47 structural criteria total** (10 + 7 + 10 + 10 + 10). `final-reviewer` consumes the five specialist verdicts and produces the final aggregated **PASS / FAIL** determination — it adds no new criteria of its own.

**Runtime behavior is verified by the Acceptance Tests, not by manual checking.** A green `tests/acceptance/` suite (from Step 4) is the evidence of correct behavior. This skill does **not** require manual click-through or a preview launch — manual verification is not mandatory (PRD Non-Goal).

## Flow

1. Confirm the Step 1–4 deliverables exist. If a required artifact is missing, instruct the user to complete the corresponding step and stop.
2. Run `prd-reviewer`, then `us-reviewer`, then `plan-reviewer`, then `code-reviewer`, then `at-reviewer` — **serially**, collecting each verdict before starting the next.
3. Run `final-reviewer` over the five specialist verdicts to produce the aggregated PASS / FAIL.
4. Present the verdict and the per-deliverable notes in one message. On FAIL, name the failing criteria so Step 4 can address them; on PASS, the Issue is ready for `merging-and-deploying`.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| PRD / US / Plan / Code / AT review verdict | **reviewing-deliverables** (this skill) |
| Plan + AT spec → green AT + production code | running-atdd-cycle (Step 4, #191) |
| Merge + deploy + post-deploy AT regression | merging-and-deploying (Step 6, #193) |
| Runtime behavior verification | the Acceptance Tests (`tests/acceptance/`, green at Step 4) |
| Parallel-session conflict, `in-progress` label management | skill-gate (#197) |

This skill **does not** add or remove the `in-progress` label — that is skill-gate's responsibility. This skill **does not** merge, deploy, or write code — it only reviews.

## Integration

- **Upstream:** `running-atdd-cycle` (its green Acceptance Tests and production code are the primary review targets)
- **Downstream:** `merging-and-deploying` (proceeds only on a PASS verdict)
