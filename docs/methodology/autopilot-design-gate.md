# autopilot Design-Approval Gate

> **Loaded by:** `skills/autopilot/SKILL.md` (Flow step 3, the design-approval User gate).

The design-approval gate is the **middle** of autopilot's three fixed User gates (AL-1). After the design phase converges `user-stories.md` / `plan.md` / `acceptance-tests.md` to near-green, autopilot **stops** and presents them to the human. Explicit approval freezes the design anchor and unlocks the impl phase — ATDD never starts before this gate.

This file holds the gate's detailed presentation contract; `skills/autopilot/SKILL.md` carries a loader stub that references it. The split keeps autopilot SKILL.md within its line-budget pin (DEVELOPMENT.md § SKILL.md Line-Budget Raises, #283) — the third raise of `tests/test_autopilot_skill.bats` is forbidden, so the AskUserQuestion detail lives here instead.

## Presentation (AskUserQuestion, selection UI)

Present the near-green deliverables and ask via **AskUserQuestion** (per `docs/guides/skill-authoring-guide.md` (a)/(b)/(c)):

- header: `"Approve design?"` (≤12 chars)
- options (the first is the one-tap approval; the rest are context-specific send-backs, one per design artifact):
  1. `"(Recommended) 承認 (ok)"` — approve the whole design set and proceed to ATDD (impl phase)
  2. `"User Stories を修正"`
  3. `"Plan を修正"`
  4. `"Acceptance Tests を修正"`
- multiSelect: false

```
Recommended: 承認 (ok) — reply 'ok' to accept, or name the artifact(s) to revise
```

The `(Recommended)` approval is always the **first** option so the human approves with one tap. The three send-back options map to the three design artifacts (user-stories / plan / acceptance-tests), so a rejection can name its target without free-text.

### Other (free-text) — harness-auto

The `Other` option is **auto-provided by the harness — never list it manually** (skill-authoring-guide (b)/(c)). When the human picks `Other`, their free text flows into the **existing natural-language feedback route** unchanged: it is treated exactly as a non-`ok` rejection comment (see Semantics below).

### Fallback (non-selection-UI channels)

On channels without selection UI (headless / cron), the `Recommended: ... — reply 'ok'` line above is the fallback: the human approves with the legacy `ok` text input, exactly as before. The gate question text is unchanged for those channels.

The gate prompt text remains:

> `設計成果物（user-stories / plan / acceptance-tests）を承認しますか? 'ok' で ATDD（impl phase）へ進みます。修正点があればコメントしてください。`

## Diff-in-body (mandatory, #275)

The gate message itself must carry the evidence, inline in BOTH the in-session message and the GitHub gate comment — complementing #267: deliverable bodies still travel as the Draft PR diff; the inline hunks are the decision evidence, not a replacement channel.

- On every **re-presentation** after fixes (re-presentation = the gate of a run re-invoked with `rejectionFindings`, #261; anything else is a first presentation), show the actual diff hunks of what changed (```diff blocks organized per finding, with the key lines called out — *key lines* = lines that directly implement an AC, change a public interface, or are quoted in a rejection finding).
- On **first presentation**, show each artifact's key decisions with file/line references — *key decision* = a choice that, if reversed, changes at least one AC or the plan's step structure; formatting choices and facts derivable from the Issue body (#254) do not qualify.
- Never present a summary-only gate that makes the user ask for the diff.

## Semantics (unchanged — selection only changes presentation, AL-1)

Selecting `承認 (ok)` (or replying `ok`) approves the **whole** deliverable set and enters the impl phase. Any other selection — including a send-back option, an `Other` free-text comment, or a partial approval like「A は ok / B は要修正」— rejects the **whole deliverable set**（部分承認は承認ではない）; never enter the impl phase on it (#261).

On rejection:

1. Split the comment **セクション単位** into findings（1 セクションの指摘 = 1 finding — never collapse multiple points into one）.
2. Each finding carries `priority`（0 = blocker unless the human states a severity）and `evidence_ref` = that section's human comment verbatim (a chosen send-back option counts as that section's comment).
3. Re-invoke the Workflow with `args = { issue: NNN, phase: 'design', rejectionFindings: [...] }` (a JSON object, #256) so they reach iteration 1's generate verbatim. MAX_ITERATIONS restarts (human intervention = a new convergence cycle) while sameness history is kept.

Changing the gate to selection-UI presentation changes **only how the choice is offered** — the approval / rejection semantics above are invariant.

## bugfix route — cause-agreement gate (#308)

On the **bugfix route** (`fixing-bugs`), this middle gate functions as a **cause-agreement** gate rather than a design-approval gate. The bugfix route writes no user-stories / plan / acceptance-tests, so the **approval target** is not those design artifacts but `debugging` Step 5's **root-cause classification (Type A/B/C, evidence 付き) + the failing reproduction test (赤)**. This is a **specialization of the same middle gate, not a fourth gate and not a removal** — the gate count stays three (AL-1). The approval target is non-empty (classification + repro test), so AL-1's "ATDD never starts before that gate" is preserved: the minimal fix begins only after the human agrees the cause.

This **cause-agreement** specialization is stated identically in `docs/methodology/autopilot-iron-law.md` (AL-1 middle-gate specialization). Both docs name the bugfix middle gate the **cause-agreement** gate and name the same approval target (root-cause classification + failing reproduction test), so the two never drift apart. The presentation contract above (AskUserQuestion, `(Recommended)` approval first, whole-set semantics, diff-in-body) is reused as-is; only the **named approval target** changes for the bugfix route.
