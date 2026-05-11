---
name: verify
description: "Evidence-based completion verification against all acceptance criteria. Must run before claiming work is done. No claims without evidence."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# verify Skill

<HARD-GATE>
Do NOT invoke ship or claim work is complete until ALL ACs have FRESH verification evidence from commands executed in THIS session. No exceptions.
</HARD-GATE>

## State Gate (required)

1. **Check `in-progress` label:** `gh issue view <number> --json labels --jq '[.labels[].name] | index("in-progress")'`
   - Present: proceed.
   - Missing: STOP. "Issue #N does not have `in-progress` label. Run `atdd` first."
2. **Check implementation branch:** Verify current branch is not `main`.
   - On `main`: STOP. "Cannot verify on main. Check out the implementation branch first."

## Iron Law

NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.

"should work", "looks correct", "probably passes" are NOT evidence. Only command output is evidence.

**FRESH means NOW:** Execute in this session, in this message. Do not use cached results, previous session output, or sub-agent reports.

## Spec Authority Check (before Verification Flow)

Resolve the authoritative AC source via `bash lib/spec_check.sh`:

1. `slug=$(bash lib/spec_check.sh derive_slug <issue>)`; AC6 fallback applies (missing / continuation-fallback / tbd-persona, all prefixed `[spec-warn]`).
2. `status=$(bash lib/spec_check.sh spec_status "$slug")` — tiebreak:
   - `approved` / `implemented` → **spec is authoritative.**
   - `draft` / `deprecated` → Issue comment ACs win; emit `[spec-warn] draft:` or `[spec-warn] deprecated:`.
3. Report divergences using `docs/methodology/us-ac-format.md` § Spec ↔ Issue Divergence Matrix (5 patterns: Added / Removed / Modified / Reordered / Status drift).

Full matrix, fallback cases, and examples: `docs/guides/spec-reference.md`.

## Verification Flow

1. Read ACs from the authoritative source determined above
2. For each AC, identify the verification command:
   - Unit test AC → run specific test: `[test command] [test file/class]`
   - Snapshot test AC → run snapshot tests
   - E2E test AC → run E2E suite
   - Build AC → run build command
3. Execute each command
4. Read the full output
5. Map output to AC: PASS with evidence or FAIL with reason

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
- Return to `atdd` skill to fix

## Status Output

**Autopilot mode only** (ARGUMENTS contains `--autopilot`). Skip in standalone mode.

Output a `skill-status` fenced code block as the **last element** of your response at every terminal point.

Terminal points:
- **COMPLETE:** All ACs pass with fresh evidence and ship about to be invoked.
- **PENDING:** Waiting for user input.
- **BLOCKED:** State Gate failed.
- **FAILED:** One or more ACs failed -- return to atdd.

```skill-status
SKILL_STATUS: COMPLETE | PENDING | BLOCKED | FAILED
PHASE: verify
RECOMMENDATION: <next action or error description in one sentence>
```

Examples:

```skill-status
SKILL_STATUS: COMPLETE
PHASE: verify
RECOMMENDATION: All ACs verified. Running ship.
```

```skill-status
SKILL_STATUS: BLOCKED
PHASE: verify
RECOMMENDATION: Issue #N does not have in-progress label. Run atdd first.
```

```skill-status
SKILL_STATUS: FAILED
PHASE: verify
RECOMMENDATION: AC3 failed: test output shows assertion error. Return to atdd to fix implementation.
```

See `docs/guides/skill-status-spec.md` for full field definitions, BLOCKED vs FAILED distinction, and autopilot action matrix.

## If All ACs Pass

- Post verification results as Issue comment
- "All verification items passed. Running `atdd-kit:ship` to finalize the PR."
- Invoke `atdd-kit:ship` via the Skill tool.

## Red Flags (STOP)

| Thought | Reality |
|---------|---------|
| "Tests should pass now" | RUN the verification. "Should" is not evidence. |
| "I'm confident this works" | Confidence is not evidence. Run the command. |
| "Just this once I'll skip lint" | No exceptions. Run every check. |
| "The sub-agent said it passed" | Verify independently. Trust no report without fresh output. |
| "I already ran these tests earlier" | Earlier is not now. Run FRESH. |
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
