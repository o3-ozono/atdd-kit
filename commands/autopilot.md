---
description: "Run an Issue in autopilot — autonomously converge its deliverables to near-green. Invoked as /atdd-kit:autopilot <issue-number> (e.g. autopilot 24)."
---

# /atdd-kit:autopilot

Explicit entry point for the **autopilot** (半自動運転) convergence loop. Runs the `converging-deliverables` skill against the given Issue, narrowing human involvement to two gates — **AC approval** at the start and **merge** at the end — and looping `generate → review → fix` until the satisfaction oracle holds.

## Usage

```
/atdd-kit:autopilot <issue-number>
```

Example: `/atdd-kit:autopilot 24` runs autopilot on Issue #24.

## What it does

1. Parse the Issue number from `$ARGUMENTS` (the first integer). If none is given, ask which Issue to run — do not guess.
2. **Precondition (AL-1, the first human gate):** the Issue must already have a **human-approved, immutable AC set** (produced via `defining-requirements` + `extracting-user-stories`). If the AC is not approved, stop and route to that gate. autopilot never invents or approves its own AC.
3. Invoke the **`converging-deliverables`** skill with that Issue number. That skill owns the loop, the satisfaction oracle, and the safety rails — governed by the autopilot Iron Law (`docs/methodology/autopilot-iron-law.md`, AL-1…AL-6).
4. autopilot stops at a **near-green Issue handed to the human merge gate** (AL-1). It never merges.

## Notes

- `converging-deliverables` opts into the **Workflow tool**; expect a multi-agent run.
- The satisfaction oracle is `AND(deterministic AT green, AC→AT coverage green, reviewer overall_correctness = correct, confirmed P0/P1 = 0)` — AT pass/fail is decided by the test command's exit code, never by an LLM (AL-3).
- Non-convergence / budget overrun / repeated identical failure → **halt + escalate** with `COMPLETED_WITH_DEBT` (AL-5); autopilot never silently loops forever or fakes green.
