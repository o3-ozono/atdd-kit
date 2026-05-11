---
name: defining-requirements
description: "Use when starting a new Issue to explore the problem space, define the PRD, and produce a structured requirements document."
---

# Defining Requirements

Step 1+2 of the atdd-kit v1.0 flow. Take an Issue number, walk the author through the 6 PRD sections one question at a time, and write `docs/issues/<NNN>/prd.md` based on `templates/docs/issues/prd.md`.

**Scope ends at the PRD.** User Story extraction (incl. persona-less Connextra form and constraint stories) is owned by `extracting-user-stories` (Step 3, #189). This skill does not write User Stories.

## Trigger

- **Explicit:** `/atdd-kit:defining-requirements <issue-number>`
- **Keyword-detected (confirm before invoking):** When user messages mention PRD authoring intent (e.g. "PRD", "要件定義", "Issue NNN を整理して"), ask `Run defining-requirements skill on <issue>? Y/n` before starting. Auto-invocation without confirmation is forbidden by the v1.0 Step B progression rule (#179).

## Input

- Issue number (command-line argument or recognized in a user message)
- Issue body / title / labels read via `gh issue view <NNN> --json title,body,labels`

No other inputs. No Context Block. No resume of existing `docs/issues/<NNN>/prd.md`.

## Output

| Artifact | Path |
|----------|------|
| PRD file | `docs/issues/<NNN>/prd.md` (copied from `templates/docs/issues/prd.md`, filled in) |

No Issue comment, no `skill-status` fenced block.

## Flow

1. Read the Issue (`gh issue view`).
2. **Section 1 — Problem** (one question): "Describe the concrete pain. Separate the current state and the consequence."
3. **Section 2 — Why now** (one question): "Why does this need to happen now? Deadlines, triggers, opportunity cost?"
4. **Section 3 — Outcome** (one question): "What measurable state is reached when done?"
5. **Section 4 — What** (one question): "List in-scope features or changes."
6. **Section 5 — Non-Goals** (one question): "List intentionally excluded items with one-line rationale each."
7. **Section 6 — Open Questions** (one question): "List unresolved decisions, or state 'none remain'."
8. **Approval gate.** Present all 6 sections merged into the PRD template structure, then ask:
   > `Approve PRD? Reply 'ok' to write, or name a section to revise.`
   Revisions loop back to that section. Do not proceed without explicit `ok`.
9. **Write artifact.** `cp templates/docs/issues/prd.md docs/issues/<NNN>/prd.md`, then fill in each section in place.

Each section step is one question at a time. Do not bundle multiple sections into a single prompt.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Issue → PRD | **defining-requirements** (this skill) |
| PRD → User Stories (persona-less Connextra, constraint stories) | extracting-user-stories (Step 3, #189) |
| Plan + Acceptance Tests | writing-plan-and-tests (Step 4, #190) |
| ATDD double-loop implementation | running-atdd-cycle (Step 5, #191) |
| PRD / US / Plan / Code / AT review | reviewing-deliverables (Step 6, #192) |
| Parallel-session conflict, `in-progress` label management | skill-gate (#197) |

This skill **does not** spawn reviewer subagents — PRD review happens at Step 6. This skill **does not** add or remove the `in-progress` label — that is skill-gate's responsibility.

## Integration

- **Upstream:** `session-start` (may suggest this skill in Recommended Tasks)
- **Downstream:** `extracting-user-stories` (consumes `docs/issues/<NNN>/prd.md`)
