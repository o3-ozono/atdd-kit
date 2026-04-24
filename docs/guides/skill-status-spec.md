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
NEXT_REQUIRED_ACTION: <action>   # optional
```

## Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `SKILL_STATUS` | enum | Required | Outcome status. See valid values below. |
| `PHASE` | string | Required | Skill name that produced the block (e.g., `discover`, `plan`, `atdd`, `verify`, `ship`). |
| `RECOMMENDATION` | string | Required | Human-readable next action or error description. **Informational only** — autopilot must NOT use this field for branching logic. |
| `NEXT_REQUIRED_ACTION` | enum | Optional | Machine-readable dispatch directive for autopilot when `SKILL_STATUS: COMPLETE`. Canonical Source of valid values (see below). When absent, autopilot falls back to the `SKILL_STATUS` Action Matrix. |

## Valid Values for SKILL_STATUS

| Value | Meaning |
|-------|---------|
| `COMPLETE` | Skill reached its normal terminal point. All required outputs were produced. |
| `PENDING` | Skill is waiting for external input (e.g., user approval mid-flow). Not yet complete. |
| `BLOCKED` | A precondition was not met or the current state prevents continuation. Human action can unblock. |
| `FAILED` | An unrecoverable structural or environment error occurred. Human must diagnose root cause. |

## Valid Values for NEXT_REQUIRED_ACTION (Canonical Source)

This table is the sole source of truth for `NEXT_REQUIRED_ACTION` enum values. Skill outputs and
autopilot dispatch tables must reference these exact strings. Adding, renaming, or removing a value
requires updating this table first; downstream consumers (skills, autopilot) must be updated in the
same PR.

| Value | Emitted By | Autopilot Required Action |
|-------|------------|---------------------------|
| `spawn_ac_review_agents` | `discover` (autopilot mode) on `COMPLETE` | In the same assistant response turn as receiving `skill-status`, issue Agent tool calls to spawn the AC Review Round agents (per task type). Do not emit intermediate user-facing text before the Agent tool calls. |
| `proceed_to_next_phase` | reserved | Advance to the next autopilot phase per the phase sequence. |
| `await_user_input` | reserved | Wait for user input; do not advance. |
| `halt` | reserved | Stop autopilot; surface RECOMMENDATION to user. |

**Field policy:** `NEXT_REQUIRED_ACTION` is optional. When omitted (the common case for existing
skills), autopilot uses the `SKILL_STATUS` Action Matrix unchanged — this preserves full backward
compatibility with pre-2.5.0 skill-status consumers.

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

### COMPLETE with NEXT_REQUIRED_ACTION (autopilot dispatch)

```skill-status
SKILL_STATUS: COMPLETE
PHASE: discover
RECOMMENDATION: AC draft ready; spawning AC Review Round
NEXT_REQUIRED_ACTION: spawn_ac_review_agents
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
| `COMPLETE` | If `NEXT_REQUIRED_ACTION` is present, use the Supplementary Dispatch for COMPLETE (below). Otherwise, proceed to next phase per the phase sequence. |
| `PENDING` | Wait for external input (user approval); do not advance |
| `BLOCKED` | Stop current phase. Post RECOMMENDATION as Issue comment. STOP and wait for user. |
| `FAILED` | Stop autopilot. Post RECOMMENDATION as Issue comment. Report to user. |
| (any other value) | Treat as `PENDING` |

### Supplementary Dispatch for COMPLETE

When `SKILL_STATUS: COMPLETE` and `NEXT_REQUIRED_ACTION` is present, autopilot resolves the
required action by matching the directive against the Canonical Source above. The dispatch is
machine-readable: do not derive intent from `RECOMMENDATION` text.

| NEXT_REQUIRED_ACTION | Autopilot Required Action |
|---|---|
| `spawn_ac_review_agents` | In the same assistant response turn as receiving `skill-status`, issue Agent tool calls to spawn the AC Review Round agents. Do not end the response with text-only before the Agent tool calls. |
| `proceed_to_next_phase` | Advance to the next phase per the phase sequence (equivalent to the baseline `COMPLETE` action). |
| `await_user_input` | Wait for user input; do not advance. |
| `halt` | Stop autopilot; surface `RECOMMENDATION` as Issue comment. |
| (any other value) | Log and treat as if `NEXT_REQUIRED_ACTION` were absent (fall back to the baseline `COMPLETE` action). |

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
