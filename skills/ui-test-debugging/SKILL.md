---
name: ui-test-debugging
description: "Auto-triggers on CI UI Test failures in PRs. Fires on keywords like 'UI test failed', 'CI test failure', 'XCUITest failed', 'test crash'."
---

# ui-test-debugging -- CI UI Test Failure Diagnosis

<HARD-GATE>
Do NOT write fix code until diagnosis is complete (all steps finished and report posted). This skill is for diagnosis and reporting ONLY. Fixes go through the normal atdd workflow after diagnosis.
</HARD-GATE>

Diagnose CI UI Test failures through structured analysis: CI log retrieval, error classification, local reproduction, evidence collection, root cause analysis, and structured PR comment reporting.

## When to Use

- CI UI Test (XCUITest, XCTest UI) has failed on a PR
- User reports a UI test failure or test crash in CI
- PR checks show test failures that need investigation

## Step 1: CI Failure Log Retrieval and Failed Test Identification

Retrieve CI failure information and identify which tests failed.

1. **Get the PR's failed CI run:**
   ```
   gh run view <run-id> --log-failed
   ```
   If no run ID is provided, auto-detect the latest failed run for the current PR.

2. **Check for Allure report JSON:**
   - Look for `summary.json` in the Allure report directory
   - Look for `data/test-results/*.json` files for detailed failure information
   - Extract: failed test names, error messages, failure step hierarchy

3. **Allure report absent fallback:**
   If Allure report JSON does not exist (e.g., build failed before tests ran), continue diagnosis with CI logs only. Explicitly state: "No Allure report available — diagnosing from CI logs only."

**Output:** List of failed tests with error messages. If Allure is available, include step hierarchy.

## Step 2: CI-Specific Error Classification and Retry Proposal

Analyze error patterns to classify failures as CI-specific (infrastructure) or code-related.

### CI-Specific Error Pattern Table

| Pattern | Error Message Example | Action |
|---------|----------------------|--------|
| Simulator boot failure | `Failed to boot simulator` | CI retry |
| Timeout | `Test exceeded time allowance of 300 seconds` | CI retry or test review |
| Signal term crash | `Test crashed with signal term.` | Local reproduction |
| Assertion failure | `XCTAssertTrue failed` | Local reproduction |
| Memory pressure | `Terminated due to memory pressure` | CI retry + infrastructure investigation |

### Classification Logic

- **CI-specific errors** (simulator boot failure, timeout, memory pressure): Propose retry with `gh run rerun --failed`. Report classification.
- **Code-related errors** (assertion failure, signal term crash): Proceed to Step 3 (local reproduction).
- **Unclassified errors** (no pattern match): Default to local reproduction (safe-side fallback). Do not assume CI-specific without evidence.

## Step 3: Local Reproduction (sim-pool Integration)

Attempt to reproduce the failure locally using the exact failing tests.

### Prerequisites Check

Check if sim-pool is configured (iOS project with sim-pool hook):
- If sim-pool is **not configured** (non-iOS project, or sim-pool not set up): **Skip local reproduction entirely.** Complete diagnosis using CI logs and Allure data only. Include guidance: "sim-pool is not configured. To enable local reproduction, run `/atdd-kit:setup-ios`."
- If sim-pool is configured: Proceed with local reproduction.

### Reproduction Steps

1. Extract failing test identifiers from Step 1 (format: `TestTarget/TestClass/testMethod`)
2. Run failing tests using XcodeBuildMCP `test` tool with `-only-testing` in extraArgs:
   - If multiple tests failed, run them all together in a single invocation
   - sim-pool hook automatically assigns an ephemeral simulator clone
3. **Maximum 3 attempts.** Record pass/fail for each attempt.
4. Based on results:
   - **Any failure reproduced:** Proceed to Step 5 (evidence collection)
   - **All 3 attempts pass:** Proceed to Step 4 (flaky detection)

## Step 4: Flaky Detection

If local reproduction ran 3 times and all 3 passed (failure not reproduced):

1. **Classify as flaky.** The test is intermittently failing — not a consistent code bug.
2. **Propose CI retry:** `gh run rerun --failed`
3. **Provide CI log-based analysis:** Even though the failure didn't reproduce locally, analyze the CI logs and Allure data to identify potential flaky causes (timing dependencies, race conditions, environment differences).
4. **Report:** Include flaky classification and CI retry recommendation in the diagnostic report (Step 6).

## Step 5: Evidence Collection and Multimodal Analysis

When a failure is reproduced locally, collect structured evidence for root cause analysis.

### Primary: xcresulttool Extraction

```bash
# Get structured test results summary
xcrun xcresulttool get test-results summary --path <path-to-xcresult>

# Export failure attachments (screenshots, logs)
xcrun xcresulttool export attachments --only-failures --path <path-to-xcresult> --output-path <output-dir>
```

Extract:
- Error messages and stack traces
- Failure step hierarchy (which action failed within the test)
- Failure screenshots (`.png` files)

### Multimodal Analysis

Use the Read tool to view extracted screenshot images. Analyze the UI state at the moment of failure:
- What is visible on screen?
- Does the UI state match the expected state described in the test?
- Are there unexpected alerts, loading states, or layout issues?

### Fallback: xcresulttool Unavailable

If `xcresulttool` is not available (older Xcode, non-standard setup), fall back to Allure report data only:
- Use Allure JSON (`data/test-results/*.json`) for error messages and step hierarchy
- Use Allure attachments (`data/attachments/*.png`) for screenshots via Read tool multimodal viewing
- Explicitly state: "xcresulttool unavailable — using Allure report data for analysis."

### Root Cause Analysis

Synthesize all evidence (error messages, step hierarchy, screenshots) to determine the root cause:
- **Code bug:** A genuine defect in application or test code
- **Flaky (timing):** Race condition or timing dependency
- **Flaky (environment):** CI-specific environment difference
- **Infrastructure:** CI runner or simulator infrastructure issue

## Step 6: Structured Diagnostic Report — PR Comment

Post a structured diagnostic report as a PR comment using `gh pr comment`.

### Report Template

```markdown
## UI Test Failure Diagnostic Report

**Failed test:** `TestClass/testMethod()`
**Error:** `Error message`
**Failure step:** When → Action → Sub-action

### Classification
- **Type:** Code bug / Flaky / Infrastructure
- **Local reproduction:** Reproduced N/3 attempts / Not reproduced (flaky) / Skipped (sim-pool not configured)

### Root Cause Analysis
[Analysis results based on evidence]

### Fix Proposal
[Specific fix proposal or "CI retry" for infrastructure issues]

### Evidence
| Failure screenshot |
|---|
| (screenshot image or "No screenshot available") |
```

### Required Fields by Classification

| Classification | Test Name | Error | Type | RCA | Fix Proposal | Evidence Image |
|----------------|-----------|-------|------|-----|--------------|----------------|
| **Code bug** | Required | Required | Required | Required | Required | Required |
| **Flaky** | Required | Required | Required | Required (CI log analysis) | CI retry | Optional |
| **Infrastructure** | Required | Required | Required | CI retry recommended | "CI retry" (fixed) | Not required |

## Red Flags (STOP)

These thoughts mean you are skipping diagnosis. STOP and return to Step 1.

| Thought | Reality |
|---------|---------|
| "I can see the fix from the error message" | Diagnosis first. No fix code until report is posted. |
| "Let me just fix this quickly" | This skill is for DIAGNOSIS ONLY. Fixes go through atdd. |
| "The test is probably flaky" | "Probably" is not evidence. Run local reproduction (Step 3). |
| "I'll skip local reproduction" | Only skip if sim-pool is not configured. Otherwise, reproduce. |
| "The screenshot isn't needed" | Visual evidence is critical for UI test failures. Collect it. |
