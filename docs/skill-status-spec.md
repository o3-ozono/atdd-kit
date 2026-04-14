# SKILL_STATUS Format Specification

This document defines the structured output format that core skills emit at every terminal point,
enabling autopilot to make phase transition decisions without text heuristics.

## Format

Skills output a `skill-status` fenced code block as the **last element** of the response at every
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
| `PHASE` | string | Skill name that produced the block (e.g., `discover`, `plan`, `atdd`, `verify`, `ship`). |
| `RECOMMENDATION` | string | Human-readable next action or error description. **Informational only** — autopilot must NOT use this field for branching logic. |

## Valid Values for SKILL_STATUS

| Value | Meaning |
|-------|---------|
| `COMPLETE` | Skill reached its normal terminal point. All required outputs were produced. |
| `PENDING` | Skill is waiting for external input (e.g., user approval mid-flow). Not yet complete. |
| `BLOCKED` | A precondition was not met or the current state prevents continuation. Human action can unblock. |
| `FAILED` | An unrecoverable structural or environment error occurred. Human must diagnose root cause. |

## BLOCKED vs FAILED Distinction

The boundary between BLOCKED and FAILED determines whether autopilot should wait for user action
or halt entirely.

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
PHASE: discover
RECOMMENDATION: Proceed to plan with approved ACs
```

### PENDING (waiting for user approval)

```skill-status
SKILL_STATUS: PENDING
PHASE: discover
RECOMMENDATION: Waiting for user approval of AC set
```

### BLOCKED (State Gate failed)

```skill-status
SKILL_STATUS: BLOCKED
PHASE: plan
RECOMMENDATION: Issue #58 has no discover deliverables. Run discover first.
```

### FAILED (unrecoverable error)

```skill-status
SKILL_STATUS: FAILED
PHASE: ship
RECOMMENDATION: gh pr create failed with authentication error. Check GH_TOKEN configuration.
```

## Autopilot Action Matrix

When autopilot (PO) receives a SendMessage reply from an agent that ran a skill, it evaluates
the `skill-status` block to determine the next action.

| SKILL_STATUS | Autopilot Next Action |
|---|---|
| `COMPLETE` | Proceed to next phase |
| `PENDING` | Wait for external input (user approval); do not advance |
| `BLOCKED` | Stop current phase. Post RECOMMENDATION as Issue comment. STOP and wait for user. |
| `FAILED` | Stop autopilot. Post RECOMMENDATION as Issue comment. Report to user. |
| (any other value) | Treat as `PENDING` |

## Fallback: No SKILL_STATUS Block Found

If the received message contains no `skill-status` block:

1. Post a warning Issue comment: "Agent returned output without SKILL_STATUS block. Manual verification required."
2. STOP. Do not advance to the next phase.
3. Report to user: which agent, which phase, and the raw message received.

**Do NOT** attempt to infer skill completion from message text. Only `skill-status` blocks are authoritative.

## Scope

This format applies to the 5 core skills only:

- `discover`
- `plan`
- `atdd`
- `verify`
- `ship`

Non-core skills (bug, issue, ideate, session-start, skill-gate, etc.) do not output `skill-status` blocks.

## Autopilot Mode Only

`skill-status` blocks are output **only when the skill is invoked with `--autopilot` in ARGUMENTS**.
Standalone invocations (user-facing sessions) do not output this block.
