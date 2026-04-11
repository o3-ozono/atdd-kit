# Bug Fix Process

> **Loaded by:** bug skill, discover skill

## A/B/C Root Cause Classification

Classify every bug into one of three categories. The classification determines the fix approach.

| Class | Root Cause | Fix Approach |
|-------|-----------|--------------|
| **A: AC Gap** | Not covered by any AC (spec gap) | Add AC -> implement via ATDD |
| **B: Test Gap** | AC exists but tests are insufficient | Add tests -> fix implementation |
| **C: Logic Error** | Tests exist but implementation is wrong | Add regression test -> fix logic |

## Test Layer Selection

Choose the test layer based on the nature of the bug.

| Bug Type | Test Layer |
|----------|-----------|
| Logic error (calculations, conditionals) | Unit |
| State management (lifecycle, race conditions) | Integration |
| Visual glitch (layout, styling) | Snapshot |
| Flow anomaly (navigation, data flow) | E2E |

## Parallel Pattern Search

When fixing a bug, search for the same pattern elsewhere in the codebase.

| Occurrences | Action |
|-------------|--------|
| 1-2 | Fix in the same PR |
| 3+ | Create a separate refactoring Issue |

## Decision Flow

```
Identify bug root cause
  |-- No Story/AC covers this operation path
  |     -> Class A: ATDD double-loop
  |-- Story/AC exists but tests don't cover this case
  |     -> Class B: Add test cases
  |-- Tests exist but implementation has a logic error
        -> Class C: Regression test
```

## Step Precautions

| Step | Do | Don't |
|------|-----|-------|
| 1. Reproduce | Record reproduction steps in the Issue | Fix by reading code alone without reproducing |
| 2. Investigate | Read logs and code to identify root cause | Guess without evidence |
| 3. Classify | Record A/B/C classification in the Issue | Start fixing without classifying |
| 4. Test | Write test matching the classification's TDD cycle | Write tests after the fix |
| 5. Fix | Minimal fix to pass the test | Fix everything at once |
| 6. Pattern search | Keep scope small -> same PR; large -> separate Issue | Fix only one spot and ignore similar cases |
| 7. Verify | CI must be all green | Only verify locally |

## Bug Fix TDD Steps

1. **Reproduce** -- Establish reliable reproduction steps
2. **Investigate** -- Identify the root cause
3. **Classify** -- Assign A, B, or C
4. **Test** -- Write a test that reproduces the bug (confirm RED)
5. **Fix** -- Minimal fix to pass the test (GREEN)
6. **Pattern search** -- Look for the same bug pattern elsewhere
7. **Full verification** -- Confirm all existing tests still pass

## Fix Proposal Format

After investigation, present the proposal before starting the fix:

```
## Fix Proposal

**Classification:** A / B / C -- <explanation>
**Root Cause:** <what is actually broken and why>
**Fix Location:** <file:line>
**Parallel Patterns:** <N other occurrences found / none>
**Effort:** Small / Medium / Large
**User Impact:** High / Medium / Low -- <reason>
**Priority:** P1 / P2 / P3

-> Proceed with fix?
```
