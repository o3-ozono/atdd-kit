# Plan Review: QA Perspective

**Issue:** #26 — fix: security hardening for pr-screenshot-table.sh and .gitignore
**Reviewer:** QA Agent
**Date:** 2026-04-12

## Overall Verdict: PASS

Plan covers all 4 ACs with appropriate test layers, good isolation, and clear AC-to-test traceability. Two minor findings (F1, F2) noted below — neither is a blocker.

全 AC を BATS/grep 構造テストで検証する方針は、このリポジトリのテスト戦略として妥当。

## Criterion Results

### Q1: Test layer appropriateness — PASS

| AC | Proposed Layer | Verdict | Rationale |
|----|---------------|---------|-----------|
| AC1: AWK code injection | Unit (BATS) | Correct | Tests AWK section replacement output with controlled input. No external dependencies needed — the AWK logic can be exercised by piping text through the function/script fragment. Unit layer is appropriate because this is pure text transformation. |
| AC2: Safe image_paths expansion | Unit (BATS) | Correct | Array expansion correctness with spaces in paths is a pure shell behavior test. Unit layer is the right choice — no need for integration with gh CLI or node. |
| AC3: PR number input validation | Unit (BATS) | Correct | Exit code and error message on invalid input is a classic unit test pattern. The validation check (`[[ "$PR_NUMBER" =~ ^[0-9]+$ ]]`) fires before any external calls (gh, git), so no mocking needed. |
| AC4: .gitignore pattern hardening | Unit (BATS) | Correct | `git check-ignore` is a local git operation that works in any `git init` directory. No remote, no gh CLI, no node required. BATS_TEST_TMPDIR with `git init` provides full isolation. |

**Outer Loop (Integration):** The plan correctly identifies the outer loop as Integration (BATS) for CI script defensive fixes. Since all 4 ACs are defensive hardening of an existing script (no UI, no user interaction changes), the outer loop being integration-level is appropriate. The individual AC tests at unit level provide sufficient granularity.

### Q2: Coverage completeness — PASS (with finding F1)

| AC | Conditions to test | Coverage | Gaps |
|----|-------------------|----------|------|
| AC1 | (1) Normal path replacement works, (2) Special chars in SECTION_FILE path don't cause injection, (3) AWK `-v` passes value safely | Covered | None |
| AC2 | (1) Paths with spaces handled correctly, (2) Multiple images processed, (3) Empty image list handled | Covered | **F1: boundary — single image path** (see below) |
| AC3 | (1) Valid integer accepted, (2) Non-integer rejected with exit 1, (3) Empty string rejected, (4) Negative number rejected, (5) Mixed alphanumeric rejected | Covered | None |
| AC4 | (1) `*.local.*` matches `foo.local.json`, (2) `*.secret` matches `db.secret`, (3) `*.secrets` matches `app.secrets`, (4) Existing patterns still work | Covered | None |

**F1 (Minor):** AC2 tests should include a boundary case for a single image path (array with one element). This ensures the array expansion works correctly when there is no word-splitting ambiguity. Severity: Low — the implementation is straightforward bash array expansion, but the test would strengthen confidence.

### Q3: Test isolation — PASS

| AC | External dependencies | Isolation approach | Verdict |
|----|----------------------|-------------------|---------|
| AC1 | None | Pure text piped through AWK. Uses BATS_TEST_TMPDIR for temp files. | Fully isolated |
| AC2 | None | Shell array expansion test. No filesystem or network needed. | Fully isolated |
| AC3 | None | Script invocation with invalid args. Exits before any gh/git/node calls due to early validation. | Fully isolated |
| AC4 | `git` (local only) | `git init` in BATS_TEST_TMPDIR, then `git check-ignore`. No remote needed. | Fully isolated |

No tests require: gh CLI authentication, node/npm, git remote access, or network connectivity. All tests can run in CI without special setup.

**Note on AC1 test isolation:** The plan correctly isolates the AWK logic test from the full script. Testing the AWK replacement inline (extracting the AWK command into a testable unit) avoids needing to mock `gh pr view`, `gh pr edit`, `git fetch`, etc. This is the right approach.

### Q4: Regression risk — PASS (with finding F2)

| Change | Regression risk | Mitigation in plan |
|--------|----------------|-------------------|
| AC1: AWK `-v` refactor | Low — functionally equivalent transformation | Test verifies same output as before with the new syntax |
| AC2: String concat to array | Medium — changes how arguments are passed to `node` script | Test verifies correct expansion; `shellcheck` SC2086 fix |
| AC3: Add validation at line 24 | Very Low — additive change, no existing code modified | New guard clause before existing logic |
| AC4: Append to .gitignore | Very Low — additive, no existing patterns modified | Test verifies existing patterns still match |

**F2 (Minor):** The plan should explicitly note that AC2's array change affects line 183 where `node "${SCRIPT_DIR}/upload-image-to-github.mjs"` is called with `$image_paths`. The current code uses `# shellcheck disable=SC2086` to intentionally allow word splitting. After converting to an array, the shellcheck disable comment should be removed (or it becomes misleading dead code). This is a cleanup detail, not a blocker.

**Existing test suite:** The proposed test file `tests/test_pr_screenshot_security.bats` is a new file and does not modify any existing tests. The changes to `scripts/pr-screenshot-table.sh` are defensive hardening that preserve existing behavior — the AWK output is the same, image paths are passed the same way (just safely), and PR number validation is additive. No existing BATS tests reference `pr-screenshot-table.sh`, so regression risk to the existing test suite is zero.

### Q5: Test naming and structure — PASS

| Criterion | Expected (from test_check_plugin_version.bats pattern) | Plan | Verdict |
|-----------|--------------------------------------------------------|------|---------|
| File location | `tests/` directory | `tests/test_pr_screenshot_security.bats` | OK |
| File naming | `test_<descriptive_name>.bats` | `test_pr_screenshot_security.bats` | OK |
| setup() function | Uses `BATS_TEST_TMPDIR`, creates temp fixtures | Planned | OK |
| Test naming | `@test "AC<N>: <description>"` | Planned | OK |
| AC prefix in test names | Yes (per repository convention) | Yes | OK |
| No teardown needed | Uses BATS_TEST_TMPDIR (auto-cleaned) | Yes | OK |

The proposed structure follows the established repository conventions seen in `test_check_plugin_version.bats` and other test files.

### Q6: AC-to-test traceability — PASS

| AC | Test(s) | Traceable | Notes |
|----|---------|-----------|-------|
| AC1: AWK code injection | AWK section replacement output verification with special chars in paths | Yes | Tests both normal replacement and injection-attempt paths |
| AC2: Safe image_paths expansion | Array expansion verification, spaces in paths | Yes | Tests correct argument passing to node script |
| AC3: PR number input validation | Exit code and error message on invalid input | Yes | Tests valid/invalid/edge-case inputs |
| AC4: .gitignore pattern hardening | `git check-ignore` pattern matching | Yes | Tests each new pattern individually |

Every AC maps to at least one test. Every test maps back to exactly one AC. No orphan tests. No untested ACs.

## Findings Summary

| # | Severity | Item | Status | Recommendation |
|---|----------|------|--------|----------------|
| F1 | Low | AC2: Missing single-image boundary test | INFO | Add a test case with exactly one image path containing spaces |
| F2 | Low | AC2: Remove `shellcheck disable=SC2086` comment after array conversion | INFO | Clean up the now-unnecessary shellcheck suppression |

---

## Conclusion

The test strategy and implementation plan are sound. All 4 ACs have appropriate test coverage at the unit (BATS) layer. Tests are fully isolated with no external dependencies. The proposed test file follows repository conventions. AC-to-test traceability is clear and complete.

**Verdict: PASS** — Implementation can proceed. F1 and F2 are minor improvements that can be addressed during implementation.
