---
description: "Explicitly invoke the bugfix lightweight route for a defect Issue — chains bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying, skipping the PRD/US/plan/AT spec. Middle gate is cause-agreement; merge stays a User gate."
---

# /atdd-kit:bugfix — bugfix Lightweight Route

## Usage

```
/atdd-kit:bugfix <issue-number>
```

Starts the `fixing-bugs` route for the given Issue.

## When to Use

Use bugfix when the Issue is a **defect fix** rather than new behavior:

- A bug / regression / crash in previously-working behavior
- Issue carries the `type:bug` label
- The fix is a minimal targeted change plus a regression test — no new spec needed

For new features or design-bearing changes, use `/atdd-kit:autopilot <issue>` (full feature route) or `/atdd-kit:defining-requirements <issue>` instead.

## Behavior

Delegates to `skills/fixing-bugs/SKILL.md`. The fixing-bugs route:

1. Runs the 5-skill chain `bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying`, **skipping** `defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests`.
2. Confirms the reproduction empirically (platform-aware) and encodes it as a failing test (赤→緑 oracle anchor).
3. Stops at the **cause-agreement** middle gate — the human approves `debugging` Step 5's root-cause classification + the failing reproduction test before the minimal fix begins (AL-1: ATDD never starts before that gate).
4. **Promotes to the full feature route** if the root cause is **Type A (AC Gap)**, reusing `debugging → defining-requirements`.
5. Merges only through `merging-and-deploying`'s **User merge gate** (autopilot Iron Law AL-1) — never auto-merges.

## References

- Full route: `skills/fixing-bugs/SKILL.md`
- Route determination (SoT): `docs/methodology/route-eligibility.md` (bugfix Route Signals)
- Iron Law specializations: `docs/methodology/autopilot-iron-law.md` (AL-1 cause-agreement gate, AL-3 coverage specialization)
- Full feature route entry: `/atdd-kit:autopilot <issue>` / `/atdd-kit:defining-requirements <issue>`
