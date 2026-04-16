---
name: atdd
description: "Use when implementing a ready-to-go Issue with approved ACs and plan."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# atdd -- ATDD Double-Loop TDD Implementation Skill

<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--autopilot` (user invoked directly via slash command):
- Display message: "This skill is autopilot-only. Use `/atdd-kit:autopilot <number>` instead."
- **STOP.** Do not proceed with execution.
If ARGUMENTS contains `--autopilot` (invoked by autopilot): skip this guard silently.
</AUTOPILOT-GUARD>

## State Gate (required)

1. **Check `ready-to-go` label:** `gh issue view <number> --json labels --jq '[.labels[].name] | index("ready-to-go")'`
   - Present: **New implementation.** `gh issue edit <number> --remove-label ready-to-go --add-label in-progress`
   - Missing: check Continuation Path
2. **Continuation Path:** If `ready-to-go` absent but `in-progress` present AND branch matches `<prefix>/<issue-number>-*`:
   - Session resumption. Do NOT block.
   - `git log --oneline main..<branch>` to identify completed ACs.
   - Resume from next incomplete AC.
3. **Neither label:** STOP. "Issue #N is not ready. Complete discover → plan → approval first."

### Additional Prerequisites

- [ ] Issue has approved ACs (from `discover`)
- [ ] Issue has test and implementation strategy (from `plan`)
- [ ] Work branch cut from main (or exists for continuation)
- [ ] Draft PR created (or exists for continuation)

## The Double Loop

### Outer Loop (per AC)

1. Read the AC -- understand precisely
2. Write E2E / Integration test (RED) -- story test verifying the AC
3. Confirm failure for right reason -- "function not defined" is right; "timeout" is not
4. Enter Inner Loop -- unit tests + implementation to make outer test pass
5. Confirm Outer test GREEN -- run all tests
6. Refactor -- improve structure, no behavior changes
7. Commit -- `feat: AC[N] -- [AC name] (#issue)`
8. Next AC

### Inner Loop (per implementation unit)

1. Write Unit / Snapshot test (RED) -- smallest needed piece
2. Confirm failure for right reason
3. Write minimal implementation (GREEN) -- only code to pass the test
4. Confirm all tests pass -- run ALL, not just new one
5. Refactor -- only while GREEN
6. Repeat until Outer test passes

## Iron Laws (never violate)

1. **No production code without a failing test** -- write the test first
2. **Never weaken a test to make it pass** -- fix the implementation, not the test
3. **Tests must fail for the right reason** -- "function not defined" is right; "timeout" is not
4. **1 AC = 1 commit** -- each AC completion is one atomic commit
5. **Missing AC discovered during implementation: STOP** -- go back to `discover`, add the AC, get approval, then continue

### Violation Recovery: Wrote Code Before Test?

**Delete it. Start over.** No exceptions. Sunk cost is not an argument.

## RED Phase

- Write the smallest failing test
- Name tests: `test_[action]_[condition]_[expected]`
- Use real code, not mocks, unless the dependency is external
- Confirm the test runs and fails; failure message must indicate missing functionality

## GREEN Phase

- Write minimal code to pass the test
- No extra functionality; no refactoring during GREEN
- Run ALL tests, not just the new one

## REFACTOR Phase

- Only after GREEN. Improve structure without changing behavior.
- Run tests after every change.
- Extract when a pattern appears 3+ times (not before).

## Test Layer Selection

| Subject | Layer | Tools |
|---------|-------|-------|
| Pure logic, calculations | Unit | XCTest / Jest / pytest |
| Cross-component interaction | Integration | XCTest / supertest |
| Appearance, layout | Snapshot | swift-snapshot-testing / Percy |
| Full user flows | E2E | XCUITest / Playwright / Cypress |

## Workflow

1. Read test strategy and implementation strategy from the Issue
2. Create branch: `git switch -c feat/<issue-number>-<slug>`
   - **WARNING:** Do NOT use `git push origin HEAD:<other-branch>` refspec rewriting — leaves commits unreachable, causing `ExitWorktree` to fail. Always push: `git push origin feat/<issue-number>-<slug>`.
3. Empty commit for Draft PR: `git commit --allow-empty -m "chore: start work on #<issue>"`
4. Push and create Draft PR
5. For each AC: Outer Loop → Inner Loop → Commit
6. After all ACs done → invoke `atdd-kit:verify`

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

- **Type A (AC Gap):** Add missing AC → RED → GREEN
- **Type B (Test Gap):** Write missing test for existing AC (RED) → fix implementation (GREEN)
- **Type C (Logic Error):** Write regression test reproducing the bug (RED) → fix logic (GREEN)
- All types: search for same pattern elsewhere (1-2 hits: fix in same PR; 3+: create a refactoring Issue)

## Status Output

**Autopilot mode only** (ARGUMENTS contains `--autopilot`). Skip in standalone mode.

Output a `skill-status` fenced code block as the **last element** of your response at every
terminal point. Terminal points for atdd:

- **COMPLETE:** All ACs are GREEN and verify is about to be invoked.
- **PENDING:** Waiting for user input (e.g., AC gap discovered — user must approve new AC).
- **BLOCKED:** State Gate failed (no `ready-to-go` label and no valid continuation path).
- **FAILED:** Unrecoverable error (e.g., build system broken, impossible to write a failing test).

```skill-status
SKILL_STATUS: COMPLETE | PENDING | BLOCKED | FAILED
PHASE: atdd
RECOMMENDATION: <next action or error description in one sentence>
```

Examples:

```skill-status
SKILL_STATUS: COMPLETE
PHASE: atdd
RECOMMENDATION: All ACs GREEN. Running verify.
```

```skill-status
SKILL_STATUS: BLOCKED
PHASE: atdd
RECOMMENDATION: Issue #N is not ready for implementation. ready-to-go label is missing.
```

See `docs/guides/skill-status-spec.md` for full field definitions, BLOCKED vs FAILED distinction, and
autopilot action matrix.

## Transition

When all ACs are GREEN:

> All ACs are GREEN. Running `atdd-kit:verify` for completion verification.

Invoke `atdd-kit:verify` via the Skill tool. atdd acts as the chain driver: verify -> ship.
