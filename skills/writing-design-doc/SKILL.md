---
name: writing-design-doc
description: "Use when a feature has significant trade-offs or architectural alternatives that warrant a structured design document."
---

# Writing Design Doc

On-demand, **conditional** skill (not part of the 6-step chain). Produce a structured design document **only when** a feature carries significant trade-offs or competing architectural alternatives that a Plan alone cannot settle. When the design is obvious, skip this skill — a design doc is not a required deliverable.

**Scope is the design document.** This skill captures the decision and its rationale. It does not write code, Acceptance Tests, or the Plan — those belong to the flow skills.

## Trigger

- **Explicit:** `claude skill atdd-kit:writing-design-doc <issue-number>`
- **Keyword-detected (confirm before invoking):** When a user message raises a design trade-off or alternatives ("which approach", "設計の選択肢", "trade-off", "architecture decision"), ask `Write a design doc for <issue>? Y/n` before starting.

## When to use (and when not to)

| Use it | Skip it |
|--------|---------|
| Multiple viable architectures with real trade-offs | One obvious approach |
| A decision future readers will question | Mechanical / low-risk change |
| Cross-cutting impact (data model, public API, dependencies) | Localized change covered by the Plan |

## Input

- Issue number (command-line argument or recognized in a user message).
- The PRD / User Stories under `docs/issues/<NNN>/` for context.

## Output

| Artifact | Form |
|----------|------|
| Design document | `docs/issues/<NNN>/design-doc.md` |

**Output language: Japanese (fixed).** The design document is written in Japanese.

### Document structure (Ubl 2020)

The design doc follows the Ubl 2020 form. Use these sections, in order:

1. **Context** — the problem and the forces at play; why a decision is needed now.
2. **Goals** — what the design must achieve.
3. **Non-Goals** — what is explicitly out of scope.
4. **Design** — the chosen approach, in enough detail to implement.
5. **Trade-offs** — what the chosen design costs and concedes.
6. **Alternatives** — other approaches considered and why they were not chosen.
7. **Open Questions** — unresolved points to settle before or during implementation.

## Flow

1. **Confirm a design doc is warranted.** If the design is obvious, say so and stop — do not produce a doc for its own sake.
2. **Gather context** from `docs/issues/<NNN>/` (PRD, User Stories).
3. **Draft** `docs/issues/<NNN>/design-doc.md` using the seven Ubl 2020 sections above.
4. **Record alternatives honestly** — each rejected alternative names the reason it lost.
5. **Surface open questions** rather than papering over them.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Design document (trade-offs, alternatives, decision) | **writing-design-doc** (this skill) |
| Implementation Plan + Acceptance Test spec | writing-plan-and-tests (Step 3) |
| PRD / requirements | defining-requirements (Step 1) |

This skill **does not** write the Plan, code, or tests. It produces a decision record that those steps then consume.

## Integration

- **Upstream:** — (on-demand; typically invoked alongside `writing-plan-and-tests` when a design decision blocks planning)
- **Downstream:** — (on-demand; the resulting `design-doc.md` informs `writing-plan-and-tests` and `running-atdd-cycle`)
