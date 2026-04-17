# Rin — Freeform Coder (Negative Persona)

> **Negative persona.** atdd-kit is explicitly *not* designed for this user. Documented here to make the boundary intentional and to keep scope decisions coherent.
> See [persona-guide.md](../methodology/persona-guide.md) for field definitions and creation guidelines.

## Name

Rin Akagi

## Role / Job Title

Freeform solo coder who treats AI assistants as a fast autocomplete. Writes code directly from prompts, iterates by re-running the agent, and avoids upfront structure. Has no product owner role and does not want one.

## Goals

### Primary Goal

Move from idea to working code as fast as possible, keeping momentum by letting the AI produce whatever seems useful next.

### Secondary Goal

Avoid anything that feels like "process overhead" — Issue tracking, acceptance criteria dialogues, pre-approvals, test-first discipline — so that flow state is never interrupted.

## Context

| Dimension | Detail |
|-----------|--------|
| Technical level | Intermediate to expert coder; deliberately under-invested in process tooling. |
| Environment | Often a single long chat with an AI assistant, few Issues, few PRs. May commit directly to `main`. Uses whichever AI/tool removes friction the fastest. |
| Constraints | Strong aversion to gates, approval steps, and derived artifacts (ACs, plans, specs). Will bypass or disable any tool that forces dialogue before coding. |

## Quote

> "If I wanted to fill out forms before writing code, I wouldn't be using an AI in the first place."

## Why atdd-kit Does Not Serve This Persona

atdd-kit's value proposition is the opposite: enforced Issue-driven discovery, AC derivation through dialogue, test-first implementation, and evidence-based verification. Trying to accommodate Rin would dilute every one of these guardrails.

Scope decisions should favour the Primary persona (Hiro — Solo Developer) when a request would reduce enforcement to make the workflow more "freeform." Common examples of out-of-scope requests driven by this persona:

- Letting autopilot synthesise a persona / User Story / AC set on its own without user research (see Issue #108 for the specific failure mode this avoids)
- Skipping the plan or review phase for non-trivial changes (Express mode exists only for genuinely trivial, pre-approved changes)
- Committing directly to `main` without an Issue reference
