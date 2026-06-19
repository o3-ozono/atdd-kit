---
name: running-atdd-cycle
description: "Use when a plan and draft Acceptance Tests exist and you need to implement code with TDD inner loop inside the ATDD cycle."
---

# Running ATDD Cycle

Step 4 of the atdd-kit v1.0 flow. Take an Issue number, read its `docs/issues/<NNN>/plan.md` and `docs/issues/<NNN>/acceptance-tests.md`, and drive the implementation through the **ATDD double loop**: an outer Acceptance-Test loop with a TDD loop nested inside it. Executable Acceptance Test files are written **per story** under `tests/acceptance/`, and the AT lifecycle is advanced `draft → green → regression` as the work proceeds.

**Scope ends at green Acceptance Tests plus the production code that satisfies them.** Reviewing the deliverables (PRD / US / Plan / Code / AT) is owned by `reviewing-deliverables` (Step 5, #192). This skill writes and runs tests and code; it does not review them.

## Trigger

- **Explicit:** `/atdd-kit:running-atdd-cycle <issue-number>`
- **Keyword-detected (confirm before invoking):** When user messages mention ATDD / implementation intent (e.g. "ATDD", "実装", "AT を green に"), ask `Run running-atdd-cycle skill on <issue>? Y/n` before starting. Auto-invocation without confirmation is forbidden by the v1.0 Step B progression rule (#179).

## Input

- Issue number (command-line argument or recognized in a user message)
- `docs/issues/<NNN>/plan.md` and `docs/issues/<NNN>/acceptance-tests.md`, read directly. If either is missing, instruct the user to run `writing-plan-and-tests` first and stop.

No other inputs. No Context Block.

> **Model note (#259):** when this skill runs as an autopilot impl-phase subagent, the recommended model is **Sonnet** by default; design-heavy Issues escalate to the session model (see the Model assignment section in `skills/autopilot/SKILL.md` and `agents/README.md`). The normal flow (main-session execution) is unaffected.

## Output

| Artifact | Path |
|----------|------|
| Executable Acceptance Test files (one per story) | `tests/acceptance/AT-<NNN>.*` |
| Production code | implementation files, edited in place |
| Updated AT lifecycle markers | `docs/issues/<NNN>/acceptance-tests.md` (`[draft] → [green] → [regression]`) |

**Output language: Japanese (fixed).** Test/identifier names and structural tokens (`Given`/`When`/`Then`, lifecycle markers, `RED`/`GREEN`) are kept verbatim for recognition; scenario descriptions and code comments are written in Japanese.

## ATDD double loop (C1–C5)

This skill enforces the atdd-kit ATDD interpretation as a mechanism, not advice.

- **C1 — Concrete Examples.** Each Acceptance Criterion is expressed as a Concrete Example in domain language: `Given <precondition>`, `When <action>`, `Then <expected>`. The AT file is the executable form of that example.
- **C2 — Lifecycle, RED first.** Each AT moves `draft → green → regression`. A newly written AT is `[draft]`; you **must run it and confirm it fails (RED)** before writing any production code. Only after it passes does it become `[green]`; once it joins the continuously-watched set it becomes `[regression]`. Skipping the RED confirmation is forbidden. **Test commit separation is mandatory (#334):** commit the AT file (test commit) first, observe RED, then commit the implementation separately (impl commit). This separation is the machine-verifiable basis for red→green evidence: the commit history provides a deterministic record that red was observed before implementation — no LLM self-assessment can substitute for this commit-level evidence. **A `[regression]` AT runs on every future branch, so it must never exact-pin a point-in-time value (the current plugin version, today's date, a line count) — assert the invariant instead** (e.g. plugin.json version equals the topmost CHANGELOG release heading, not `== "3.17.0"`); #289: literal version pins turned post-merge regression permanently red on the next bump.
- **C3 — TDD nested inside ATDD.** Inside the outer Acceptance-Test loop, drive production code with a TDD inner loop: write a failing unit test (RED) → minimal code to pass (GREEN) → refactor. Repeat the inner loop until the enclosing AT goes green.
- **C4 — Story unit vs unit unit.** Each Acceptance Test file is scoped to **one User Story** (`tests/acceptance/AT-<NNN>.*`, story-scoped). Each TDD test is scoped to **one unit**. The two granularities never collapse into one.
- **C5 — Two separated feedback loops.** The **External** feedback loop (ATDD, per story, outer) and the **Internal** feedback loop (TDD, per unit, inner) are kept structurally separate so each gives its own signal.

## Flow

For each User Story / AT entry in `acceptance-tests.md` (story by story):

1. **Write the AT (C1).** Express the AC as a Concrete Example (`Given` / `When` / `Then`) and encode it as an executable test at `tests/acceptance/AT-<NNN>.*`. Mark it `[draft]` in `acceptance-tests.md`.
2. **Confirm RED (C2).** Run the AT and confirm it **fails (RED)**. Never proceed past a test that has not been observed failing. **Commit the AT file now** (test commit) before writing any implementation — this commit separation is mandatory (#334): the test commit precedes the impl commit in history, providing machine-verifiable red→green evidence. **Call `record_red_evidence <red.jsonl> <test-commit-sha> <at-file>`** immediately after the test commit to record the red exit in `red.jsonl`; without this call no evidence is written and `check_red_evidence` will fail-closed (deterministic, no LLM self-assessment).
3. **TDD inner loop (C3/C5).** To make the AT pass, loop at the unit level: failing unit test (RED) → minimal implementation (GREEN) → refactor. Repeat until the outer AT passes.
4. **Advance lifecycle (C2).** When the AT passes, update its marker `[draft] → [green]` in `acceptance-tests.md`.
5. **Next story.** Move to the next AT entry. The outer loop is per story; the inner TDD loop is per unit.

After all stories are green, mark the stabilized ATs `[green] → [regression]` so they enter the continuous regression set Step 6 re-runs post-deploy.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Plan + AT spec → green AT + production code | **running-atdd-cycle** (this skill) |
| Issue → PRD | defining-requirements (Step 1, #188) |
| PRD → User Stories | extracting-user-stories (Step 2, #189) |
| Plan + Acceptance Test spec | writing-plan-and-tests (Step 3, #190) |
| PRD / US / Plan / Code / AT review | reviewing-deliverables (Step 5, #192) |
| Merge + post-deploy AT regression | merging-and-deploying (Step 6, #193) |
| Parallel-session conflict, `in-progress` label management | skill-gate (#197) |

This skill **does not** spawn reviewer subagents — code and AT review happens at Step 5. This skill **does not** add or remove the `in-progress` label — that is skill-gate's responsibility.

## Test Execution Policy (#324)

Run **impact-affected files only** during each ATDD iteration to keep the feedback loop short:

```
scripts/run-tests.sh --impact --base <base-ref>
```

claude-based e2e tests (`tests/e2e/*.bats`) follow the same impact criterion — run them only when the
change touches the skill or component they cover, not on every iteration.

For the full policy doctrine, see [`docs/methodology/test-execution-policy.md`](../../docs/methodology/test-execution-policy.md).

## Integration

- **Upstream:** `writing-plan-and-tests` (consumes its `docs/issues/<NNN>/plan.md` and `docs/issues/<NNN>/acceptance-tests.md`)
- **Downstream:** `reviewing-deliverables` (reviews the resulting code and Acceptance Tests)
