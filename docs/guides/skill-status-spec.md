# SKILL_STATUS Format Specification

This document defines the structured output format that a skill emits at a terminal point,
enabling an automated consumer (e.g. the `skill-fix` background dispatch) to make phase
transition decisions without parsing free-form text.

In v1.0 the format is emitted by the `skill-fix` skill. Any other skill MAY adopt it when it
needs to be driven programmatically.

## Format

A skill outputs a `skill-status` fenced code block as the **last element** of the response at a
terminal point (completion, block, or failure):

```skill-status
SKILL_STATUS: <value>
PHASE: <skill-name>
RECOMMENDATION: <one sentence>
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `SKILL_STATUS` | enum | Outcome status. See valid values below. |
| `PHASE` | string | Skill name that produced the block (e.g., `defining-requirements`, `writing-plan-and-tests`, `running-atdd-cycle`, `reviewing-deliverables`, `merging-and-deploying`). |
| `RECOMMENDATION` | string | Human-readable next action or error description. **Informational only** — the consumer must NOT use this field for branching logic. |

## Valid Values for SKILL_STATUS

| Value | Meaning |
|-------|---------|
| `COMPLETE` | Skill reached its normal terminal point. All required outputs were produced. |
| `PENDING` | Skill is waiting for external input (e.g., user approval mid-flow). Not yet complete. |
| `BLOCKED` | A precondition was not met or the current state prevents continuation. Human action can unblock. |
| `FAILED` | An unrecoverable structural or environment error occurred. Human must diagnose root cause. |

## BLOCKED vs FAILED Distinction

The boundary between BLOCKED and FAILED determines whether the consumer should wait for user
action or halt entirely.

| Situation | Status | Rationale |
|-----------|--------|-----------|
| State Gate fails (`in-progress` label missing) | `BLOCKED` | User can add label to unblock |
| HARD-GATE triggers (user approval required) | `BLOCKED` | User can approve to unblock |
| User rejected a proposal | `BLOCKED` | User can revise to unblock |
| External command failed with transient error | `BLOCKED` | Retrying may succeed |
| Existing HARD-GATE or State Gate precondition not met | `BLOCKED` | Human action resolves it |
| `gh` command fails with permission/auth error | `FAILED` | Structural — environment must be fixed |
| Skill invoked in wrong execution context | `FAILED` | Structural — configuration must be fixed |
| Irrecoverable state contradiction detected | `FAILED` | Structural — root cause investigation required |

**Rule of thumb:**
- `BLOCKED` = a human can unblock it by taking a specific action
- `FAILED` = a human must diagnose why the environment or state is broken

## Usage Examples

### COMPLETE (normal completion)

```skill-status
SKILL_STATUS: COMPLETE
PHASE: defining-requirements
RECOMMENDATION: Proceed to writing-plan-and-tests with approved ACs
```

### PENDING (waiting for user approval)

```skill-status
SKILL_STATUS: PENDING
PHASE: defining-requirements
RECOMMENDATION: Waiting for user approval of AC set
```

### BLOCKED (State Gate failed)

```skill-status
SKILL_STATUS: BLOCKED
PHASE: writing-plan-and-tests
RECOMMENDATION: Issue #58 has no defining-requirements deliverables. Run defining-requirements first.
```

### FAILED (unrecoverable error)

```skill-status
SKILL_STATUS: FAILED
PHASE: merging-and-deploying
RECOMMENDATION: gh pr create failed with authentication error. Check GH_TOKEN configuration.
```

## Action Matrix

When the consumer receives a reply from a skill, it evaluates the `skill-status` block to
determine the next action.

| SKILL_STATUS | Next Action |
|---|---|
| `COMPLETE` | Proceed to next phase |
| `PENDING` | Wait for external input (user approval); do not advance |
| `BLOCKED` | Stop current phase. Post RECOMMENDATION as Issue comment. STOP and wait for user. |
| `FAILED` | Stop. Post RECOMMENDATION as Issue comment. Report to user. |
| (any other value) | Treat as `PENDING` |

## Fallback: No SKILL_STATUS Block Found

If the received message contains no `skill-status` block:

1. Post a warning Issue comment: "Skill returned output without SKILL_STATUS block. Manual verification required."
2. STOP. Do not advance to the next phase.
3. Report to user: which skill, which phase, and the raw message received.

**Do NOT** attempt to infer skill completion from message text. Only `skill-status` blocks are authoritative.

## Scope

The format is emitted by the `skill-fix` skill at every terminal point. Other skills (`defining-requirements`,
`extracting-user-stories`, `writing-plan-and-tests`, `running-atdd-cycle`, `reviewing-deliverables`,
`merging-and-deploying`, `bug`, `session-start`, etc.) drive their transitions through Issue/PR labels and do
not emit `skill-status` blocks by default.
