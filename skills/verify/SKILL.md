---
name: verify
description: "Evidence-based completion verification against all acceptance criteria. Must run before claiming work is done. No claims without evidence."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# verify Skill

<HARD-GATE>
Do NOT invoke ship or claim work is complete until ALL ACs have FRESH verification evidence from commands executed in THIS session. No exceptions regardless of confidence level.
</HARD-GATE>

## State Gate (required)

Before running verification, check the Issue state:

1. **Check `in-progress` label:** `gh issue view <number> --json labels --jq '[.labels[].name] | index("in-progress")'`
   - If present: proceed to Verification Flow.
   - If missing: STOP. Report: "Issue #N does not have `in-progress` label. Run `atdd` first to implement the Issue."
2. **Check implementation branch:** Verify the current branch is not `main`. Verification must run on the implementation branch.
   - If on `main`: STOP. Report: "Cannot verify on main. Check out the implementation branch first."

## Iron Law

NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.

"should work", "looks correct", "probably passes" are NOT evidence. Only command output is evidence.

**FRESH means NOW:** Execute verification commands in this session, in this message. Do not use cached results, previous session output, or sub-agent reports. Run the command yourself and read the output.

## Verification Flow

1. **Read ACs from Issue** -- Get the complete AC list
2. **For each AC, identify the verification command:**
   - Unit test AC -> run specific test: `[test command] [test file/class]`
   - Snapshot test AC -> run snapshot tests
   - E2E test AC -> run E2E test suite
   - Build AC -> run build command
3. **Execute each command** -- Run it NOW, in this session
4. **Read the output** -- Actually read the full output, not just the exit code
5. **Map output to AC** -- For each AC, record: PASS with evidence or FAIL with reason

## Verification Checklist

```
## Verification Results

| AC | Test | Result | Evidence |
|----|------|--------|----------|
| AC1: [name] | [test command] | PASS / FAIL | [output excerpt] |
| AC2: [name] | [test command] | PASS / FAIL | [output excerpt] |
| ... | ... | ... | ... |

### Additional Verification
- [ ] Build passes with zero warnings: [command] -> [result]
- [ ] Lint passes: [command] -> [result]
- [ ] All existing tests pass: [command] -> [result]
```

## What Counts as Evidence

- Command output showing PASS with test count
- Build log showing "Build Succeeded" with 0 warnings
- Lint output showing 0 violations
- NOT: "I ran the tests and they passed" (no output shown)
- NOT: "Should be fine" / "looks good"
- NOT: Previous session's test results (must be FRESH)
- NOT: Partial test run (must run ALL tests)

## If Any AC Fails

- Report which AC failed and why
- Do NOT proceed to ship
- Go back to `atdd` skill to fix

## If All ACs Pass

- Post verification results as Issue comment
- Transition: "All verification items passed. Running `atdd-kit:ship` to finalize the PR."
- Invoke `atdd-kit:ship` via the Skill tool.

## Red Flags (STOP)

These thoughts mean you are rationalizing skipping verification. STOP.

| Thought | Reality |
|---------|---------|
| "Tests should pass now" | RUN the verification. "Should" is not evidence. |
| "I'm confident this works" | Confidence is not evidence. Run the command. |
| "Just this once I'll skip lint" | No exceptions. Run every check. |
| "The sub-agent said it passed" | Verify independently. Trust no report without fresh output. |
| "I already ran these tests earlier" | Earlier is not now. Results expire. Run them FRESH. |
| "Partial test run is enough" | Must run ALL tests. Partial results hide regressions. |
| "The build is obviously fine" | Run the build command. "Obviously" is a red flag word. |

## Gate Function Pattern

```
IDENTIFY -> what command proves this AC?
RUN -> execute the command
READ -> read the full output
VERIFY -> does output match the claim?
ONLY THEN -> state the result
```
