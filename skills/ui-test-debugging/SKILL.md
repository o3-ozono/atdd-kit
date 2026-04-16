---
name: ui-test-debugging
description: "Auto-triggers on CI UI Test failures in PRs. Fires on keywords like 'UI test failed', 'CI test failure', 'XCUITest failed', 'test crash'."
---

# ui-test-debugging -- CI UI Test Failure Diagnosis

<HARD-GATE>
Do NOT write fix code until diagnosis is complete (all steps finished and report posted). This skill is for diagnosis and reporting ONLY. Fixes go through the normal atdd workflow after diagnosis.
</HARD-GATE>

Diagnose CI UI Test failures: CI log retrieval, error classification, local reproduction, evidence collection, root cause analysis, PR comment report.

## When to Use

- CI UI Test (XCUITest, XCTest UI) failed on a PR
- User reports UI test failure or test crash in CI

## Step 1: CI Failure Log Retrieval and Failed Test Identification

1. `gh run view <run-id> --log-failed` (auto-detect latest failed run if no ID provided)
2. Check for Allure `summary.json` and `data/test-results/*.json`: extract failed test names, error messages, step hierarchy
3. No Allure report: continue with CI logs only. State: "No Allure report available — diagnosing from CI logs only."

**Output:** List of failed tests with error messages (and step hierarchy if Allure available).

## Step 2: Error Classification

| Pattern | Example | Action |
|---------|---------|--------|
| Simulator boot failure | `Failed to boot simulator` | CI retry |
| Timeout | `Test exceeded time allowance of 300 seconds` | CI retry or test review |
| Signal term crash | `Test crashed with signal term.` | Local reproduction |
| Assertion failure | `XCTAssertTrue failed` | Local reproduction |
| Memory pressure | `Terminated due to memory pressure` | CI retry + infra investigation |

- CI-specific (boot failure, timeout, memory): propose `gh run rerun --failed`
- Code-related (assertion failure, crash): proceed to Step 3
- Unclassified: default to local reproduction. Do not assume CI-specific without evidence.

## Step 3: Local Reproduction (sim-pool Integration)

If sim-pool is not configured: skip local reproduction, complete diagnosis with CI logs/Allure only. Include: "Run `/atdd-kit:setup-ios` to enable local reproduction."

If sim-pool configured:
1. Extract failing test IDs (`TestTarget/TestClass/testMethod`)
2. Run with XcodeBuildMCP `test` tool and `-only-testing` extraArgs (all failing tests in one invocation; sim-pool auto-assigns clone)
3. **Max 3 attempts.** Any failure reproduced → Step 5. All 3 pass → Step 4 (flaky detection).

## Step 4: Flaky Detection

3 attempts all passed: classify as flaky. Propose CI retry (`gh run rerun --failed`). Analyze CI logs/Allure for flaky causes (timing, race conditions, env differences). Include flaky classification in Step 6 report.

## Step 5: Evidence Collection and Multimodal Analysis

Extract with xcresulttool:
```bash
xcrun xcresulttool get test-results summary --path <path-to-xcresult>
xcrun xcresulttool export attachments --only-failures --path <path-to-xcresult> --output-path <output-dir>
```

Read screenshots via the Read tool. Analyze: UI state at failure, expected vs. actual state, unexpected alerts/loading states.

Fallback (xcresulttool unavailable): use Allure JSON (`data/test-results/*.json`) and attachments (`data/attachments/*.png`). State: "xcresulttool unavailable — using Allure data."

Root cause classification: Code bug / Flaky (timing) / Flaky (environment) / Infrastructure.

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

| Thought | Reality |
|---------|---------|
| "I can see the fix from the error message" | Diagnosis first. No fix code until report posted. |
| "Let me just fix this quickly" | DIAGNOSIS ONLY. Fixes go through atdd. |
| "The test is probably flaky" | "Probably" is not evidence. Run local reproduction. |
| "I'll skip local reproduction" | Only skip if sim-pool not configured. Otherwise reproduce. |
| "The screenshot isn't needed" | Visual evidence is critical. Collect it. |
