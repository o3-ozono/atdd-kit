---
name: debugging
description: "Root cause investigation before bug fixes. Auto-triggers on bug reports, errors, crashes, and unexpected behavior. Enforces diagnosis before code changes."
---

# debugging -- Root Cause Investigation

<HARD-GATE>
Do NOT write fix code until root cause is classified with evidence (Step 5 complete). Do NOT skip from symptoms to fixes. "I think I know the issue" is not investigation. Only evidence counts.
</HARD-GATE>

Investigate before fixing. No fix code without understanding the root cause first.

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

"I think I know the issue" is not investigation. Only evidence counts.

## When to Use

- User reports a bug, error, crash, or unexpected behavior
- A test fails unexpectedly
- Something "used to work" but doesn't anymore

## Prohibition During Investigation

- Do not write fix code until root cause is classified
- Do not guess at fixes ("let me try this")
- Diagnostic instrumentation only (minimal logging to gather evidence)

## Flow

### Step 1: Symptom Confirmation

Understand what is happening:
- **What:** Exact error message, behavior, or output
- **When:** Steps to reproduce
- **Where:** File, line, component involved
- **Since when:** Last known working state (git log, recent changes)

Ask one question at a time if information is missing.

### Step 2: Hypothesis Formation

Form 2-3 hypotheses about the root cause:

```
Based on the symptoms, possible causes:

1. [Hypothesis A] -- [reasoning]
2. [Hypothesis B] -- [reasoning]
3. [Hypothesis C] -- [reasoning]

Investigating hypothesis 1 first because [reason].
```

### Step 3: Diagnostic Instrumentation

Add **minimal** diagnostic code to gather evidence:
- Log statements at key points
- Assertions to narrow down the failure path
- Print intermediate values

This is the **only** code change allowed during investigation.

### Step 4: Evidence Collection

Run the reproduction steps with diagnostics in place. Record:
- Actual output/behavior
- Expected output/behavior
- Where the divergence occurs

### Step 5: Root Cause Classification

Classify the root cause:

| Class | Description | Next Step |
|-------|-------------|-----------|
| **A: AC Gap** | Not covered by any AC -- undefined behavior | Add AC via `discover`, then fix |
| **B: Test Gap** | AC exists but tests are insufficient | Write missing test, then fix |
| **C: Logic Error** | Tests exist but implementation is wrong | Write regression test, then fix |

Present findings:

```
## Root Cause Analysis

**Classification:** [A / B / C] -- [class name]
**Cause:** [description]
**Evidence:** [what proved this]
**Code:** [file path and line number]

Proceed to fix? [Yes / Need more investigation]
```

### Step 6: Transition to Fix

When root cause is confirmed:

> Root cause identified. Proceeding to bug fix workflow.

- **Type A:** Chain to `atdd-kit:discover` to add the missing AC
- **Type B/C:** Chain to `atdd-kit:atdd` with a regression test for the bug

## 3-Failure Escalation Rule

If you have attempted 3 or more fixes and the bug persists:

**STOP. Do NOT attempt fix #4.**

This is NOT a failed hypothesis -- this is a wrong architecture. Escalate:

1. Report the 3 attempted fixes and their results
2. Question the underlying architecture or assumptions
3. Present the pattern to the user for architectural discussion
4. Only proceed after the user confirms a new direction

## Red Flags (STOP)

These thoughts mean you are rationalizing skipping investigation. STOP and return to Step 1.

| Thought | Reality |
|---------|---------|
| "I think it's this" | Thinking is not evidence. Investigate. |
| "Quick fix for now, investigate later" | "Later" never comes. Investigate NOW. |
| "Just try changing X and see if it works" | Guessing wastes time. Form a hypothesis with evidence. |
| "This is obviously the cause" | "Obviously" is a red flag word. Prove it with evidence. |
| "Let me just try this fix" | NO. Complete Step 5 first. |
| "I've seen this before" | Past experience informs hypotheses, not conclusions. Verify. |
| "It's probably a race condition" | "Probably" requires evidence. Add diagnostic instrumentation. |

## Prohibition Checklist

- [ ] Not writing fix code (diagnostic instrumentation only)
- [ ] Hypotheses formed before diving into code
- [ ] Evidence collected before classification
- [ ] Root cause classified (A/B/C) with evidence
- [ ] User confirmed root cause before proceeding to fix
