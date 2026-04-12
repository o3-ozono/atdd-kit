---
name: atdd
description: "Use when implementing a ready-to-go Issue with approved ACs and plan."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# atdd -- ATDD Double-Loop TDD Implementation Skill

<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--autopilot` (user invoked directly via slash command):
- Display warning: "This skill is designed to run within autopilot. Use `/atdd-kit:autopilot <number>` instead."
- **Do not block execution.** Proceed normally after showing the warning.
If ARGUMENTS contains `--autopilot` (invoked by autopilot): skip this warning silently.
</AUTOPILOT-GUARD>

## State Gate (required)

Before starting implementation, verify the Issue state:

1. **Check `ready-to-go` label:** `gh issue view <number> --json labels --jq '[.labels[].name] | index("ready-to-go")'`
   - If present: **New implementation.** Remove `ready-to-go`, add `in-progress`: `gh issue edit <number> --remove-label ready-to-go --add-label in-progress`
   - If missing: check Continuation Path (below)
2. **Continuation Path:** If `ready-to-go` is absent but `in-progress` is present AND the current branch matches `<prefix>/<issue-number>-*`:
   - This is a **session resumption.** Do NOT block. Proceed with implementation from where it left off.
   - Check `git log --oneline main..<branch>` to identify completed ACs from commit messages.
   - Resume from the next incomplete AC.
3. **Neither label present:** STOP. Report: "Issue #N is not ready for implementation. Complete discover → plan → approval first."

### Additional Prerequisites

After State Gate passes, also verify:

- [ ] Issue has approved ACs (output of `discover`)
- [ ] Issue has test strategy and implementation strategy (output of `plan`)
- [ ] Work branch is cut from main (or already exists for continuation)
- [ ] Draft PR is created (or already exists for continuation)

## The Double Loop

### Outer Loop (per AC)

For each AC, run this cycle:

1. **Read the AC from the Issue** -- Understand the acceptance criteria precisely
2. **Write an E2E / Integration test (RED)** -- A story test that verifies the AC
3. **Confirm it fails for the right reason** -- "function not defined" is right; "timeout" or "syntax error" is not
4. **Enter the Inner Loop** -- Write unit tests and implementation to make the E2E test pass
5. **Confirm the Outer test is GREEN** -- Run all tests
6. **Refactor** -- Improve structure as needed (no behavior changes)
7. **Commit** -- `feat: AC[N] -- [AC name] (#issue)`
8. **Next AC**

### Inner Loop (per implementation unit)

Repeat in small increments to make the Outer test GREEN:

1. **Write a Unit / Snapshot test (RED)** -- Test the smallest needed piece
2. **Confirm failure** -- Test runs and fails for the right reason
3. **Write minimal implementation (GREEN)** -- Only the code needed to pass the test
4. **Confirm all tests pass** -- Run all tests, not just the new one
5. **Refactor** -- Only while GREEN
6. **Repeat until Outer test passes**

## Iron Laws (never violate)

1. **No production code without a failing test** -- If you catch yourself writing implementation first, STOP and write a test
2. **Never weaken a test to make it pass** -- If a test fails, fix the implementation, not the test
3. **Tests must fail for the right reason** -- "function not defined" is right; "timeout" is not
4. **1 AC = 1 commit** -- Each AC completion is one atomic commit
5. **If you discover a missing AC during implementation, STOP** -- Go back to `discover`, add the AC, get approval, then continue

### Violation Recovery: Wrote Code Before Test?

**Delete it. Start over.** No exceptions:
- Do not keep it as "reference"
- Do not "adapt" it while writing tests
- Do not look at it
- Delete means delete

Sunk cost is not an argument. Keeping unverified code is technical debt from minute one.

## RED Phase

- Write the smallest failing test
- Name tests by behavior: `test_[action]_[condition]_[expected]`
- Use real code, not mocks, unless the dependency is external
- Confirm the test actually runs and fails
- Check the failure message -- it should indicate missing functionality, not typos or import errors

## GREEN Phase

- Write the minimal code to pass the test
- Do not add functionality beyond what the test requires
- Do not refactor during GREEN -- pass first
- Run all tests, not just the new one, to catch regressions

## REFACTOR Phase

- Only after GREEN
- Improve structure without changing behavior
- Run tests after every change
- Common refactors: extract method, rename, remove duplication
- Extract when a pattern appears 3+ times (not before)

## Test Layer Selection

| Subject | Layer | Tools |
|---------|-------|-------|
| Pure logic, calculations | Unit | XCTest / Jest / pytest |
| Cross-component interaction | Integration | XCTest / supertest |
| Appearance, layout | Snapshot | swift-snapshot-testing / Percy |
| Full user flows | E2E | XCUITest / Playwright / Cypress |

## Workflow

1. Read the test strategy and implementation strategy from the Issue
2. Create branch: `feat/<issue-number>-<slug>`
3. Empty commit for Draft PR: `git commit --allow-empty -m "chore: start work on #<issue>"`
4. Push and create Draft PR
5. For each AC:
   a. Run Outer Loop (AC test)
   b. Run Inner Loop (Unit test + implementation)
   c. Commit
6. After all ACs are done -> invoke `atdd-kit:verify`

## Mandatory Checklist (after each AC)

Do not skip any item.

- [ ] Test was written before implementation
- [ ] Test failed before implementation was written
- [ ] Test failed for the right reason
- [ ] Implementation is minimal (no extra features)
- [ ] All existing tests pass (run ALL, not just new)
- [ ] Commit message follows conventions
- [ ] If `skills/*/SKILL.md` was edited: `bats tests/` run and all tests PASS
- [ ] If `skills/*/SKILL.md` was edited and `skills/<name>/evals/` exists: skill-creator eval run with no regression

## Red Flags (STOP immediately)

These thoughts mean you are rationalizing a violation. STOP and return to the correct phase.

| Thought | Reality |
|---------|---------|
| "I'll write tests later" | Tests-after are biased by implementation. Write tests FIRST. |
| "This is too simple to test" | Simple code breaks. A test takes 30 seconds. No exceptions. |
| "Just this small piece of code first" | Delete it. Write the test. Then rewrite the code. |
| "TDD is dogmatic, being pragmatic means adapting" | TDD IS pragmatic: it finds bugs before commit. |
| "The test passes on first run, that's fine" | If it didn't fail first, you don't know if it tests the right thing. |
| "I'll weaken this assertion temporarily" | Fix the implementation, not the test. Never weaken. |
| "This feature isn't in the AC but it's needed" | STOP. Go back to discover. Add the AC. Get approval. |
| "I'll skip the Outer Loop E2E test" | The Outer Loop proves the AC works end-to-end. Never skip. |

## Bug Fix Variant (A/B/C Classification)

- **Type A (AC Gap):** Add the missing AC -> write test (RED) -> implement (GREEN)
- **Type B (Test Gap):** Write the missing test for an existing AC (RED) -> fix implementation (GREEN)
- **Type C (Logic Error):** Write a regression test reproducing the bug (RED) -> fix the logic (GREEN)
- All types: search for the same pattern elsewhere (1-2 hits: fix in same PR; 3+: create a refactoring Issue)

## Transition

When all ACs are GREEN:

> All ACs are GREEN. Running `atdd-kit:verify` for completion verification.

Invoke `atdd-kit:verify` via the Skill tool. atdd acts as the chain driver: verify -> ship.
