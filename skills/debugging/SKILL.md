---
name: debugging
description: "Root cause investigation before bug fixes. Auto-triggers on bug reports, errors, crashes, and unexpected behavior. Enforces diagnosis before code changes."
---

# debugging -- Root Cause Investigation

<HARD-GATE>
Do NOT write fix code until root cause is classified with evidence (Step 5 complete). Do NOT skip from symptoms to fixes. Only evidence counts.
</HARD-GATE>

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION.** "I think I know the issue" is not evidence.

## When to Use

- Bug, error, crash, or unexpected behavior
- Test fails unexpectedly
- Something stopped working

## Prohibitions During Investigation

- No fix code until root cause is classified
- No guessing ("let me try this")
- Diagnostic instrumentation only

## Flow

### Step 1: Symptom Confirmation

Identify: What (exact error/behavior), When (steps), Where (file/line/component), Since when (`git log`). Ask one question at a time.

### Step 2: Hypothesis Formation

```
Based on symptoms, possible causes:

1. [Hypothesis A] -- [reasoning]
2. [Hypothesis B] -- [reasoning]
3. [Hypothesis C] -- [reasoning]

Investigating hypothesis 1 first because [reason].
```

### Step 3: Diagnostic Instrumentation

Add **minimal** diagnostic code only: log statements, assertions, print values. The **only** code change allowed during investigation.

### Step 4: Evidence Collection

Run reproduction steps with diagnostics. Record: actual vs. expected, where divergence occurs.

### Step 5: Root Cause Classification

| Class | Description | Next Step |
|-------|-------------|-----------|
| **A: AC Gap** | Not covered by any AC | Add AC via `discover`, then fix |
| **B: Test Gap** | AC exists, tests insufficient | Write missing test, then fix |
| **C: Logic Error** | Tests exist, implementation wrong | Write regression test, then fix |

```
## Root Cause Analysis

**Classification:** [A / B / C] -- [class name]
**Cause:** [description]
**Evidence:** [what proved this]
**Code:** [file path and line number]

Proceed to fix? [Yes / Need more investigation]
```

### Step 6: Transition to Fix

- **Type A:** Chain to `atdd-kit:discover` to add missing AC
- **Type B/C:** Chain to `atdd-kit:atdd` with regression test

## 3-Failure Escalation Rule

After 3 failed fixes: **STOP. Do NOT attempt fix #4.**

1. Report 3 attempted fixes and results
2. Question underlying architecture or assumptions
3. Present pattern to user for architectural discussion
4. Proceed only after user confirms new direction

## Red Flags (STOP)

| Thought | Reality |
|---------|---------|
| "I think it's this" | Thinking is not evidence. Investigate. |
| "Quick fix for now, investigate later" | "Later" never comes. Investigate NOW. |
| "Just try changing X" | Guessing wastes time. Form a hypothesis. |
| "This is obviously the cause" | "Obviously" is a red flag. Prove with evidence. |
| "Let me just try this fix" | NO. Complete Step 5 first. |
| "I've seen this before" | Past experience informs hypotheses, not conclusions. Verify. |
| "It's probably a race condition" | "Probably" requires evidence. |

## Prohibition Checklist

- [ ] Not writing fix code (diagnostic instrumentation only)
- [ ] Hypotheses formed before diving into code
- [ ] Evidence collected before classification
- [ ] Root cause classified (A/B/C) with evidence
- [ ] User confirmed root cause before proceeding
