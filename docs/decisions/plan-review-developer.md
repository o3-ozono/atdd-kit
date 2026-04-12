# Plan Review: Developer

**Issue:** #26 — fix: security hardening for pr-screenshot-table.sh and .gitignore
**Reviewer:** Developer Agent
**Date:** 2026-04-12

## Overall Verdict: PASS

Plan is technically sound. All 4 ACs are correctly mapped to implementation targets with appropriate techniques. bash 3.2 compatibility verified. One minor observation noted for implementer awareness.

## R1: File structure validity — PASS

| Target File | Exists | Action | Correct |
|---|---|---|---|
| `scripts/pr-screenshot-table.sh` (line 24) | Yes | Modify — PR number validation | Yes, line 24 is `PR_NUMBER="$1"` |
| `scripts/pr-screenshot-table.sh` (lines 175-183) | Yes | Modify — array conversion | Yes, lines 175-183 are the image_paths string concatenation + SC2086 disable |
| `scripts/pr-screenshot-table.sh` (lines 293-297) | Yes | Modify — AWK `-v` fix | Yes, lines 293-297 are the AWK section replacement with shell expansion |
| `.gitignore` (append) | Yes | Modify — add patterns | Yes, 16 lines currently |
| `tests/test_pr_screenshot_security.bats` | No (new) | Create | Yes, follows `tests/test_*.bats` naming convention |

No missing files. `scripts/upload-image-to-github.mjs` is correctly identified as unchanged — it accepts positional arguments (`process.argv.slice(2)`), so the array expansion change is transparent.

## R2: Implementation order risks — PASS

Plan states AC1, AC2, AC3 are independent (different locations in `pr-screenshot-table.sh`) and AC4 is fully independent (`.gitignore` only). This is correct:

- AC1 modifies lines 293-297 (AWK section)
- AC2 modifies lines 175-183 (image_paths section)
- AC3 modifies around line 24 (after `PR_NUMBER="$1"`)
- AC4 modifies `.gitignore` (append)

No overlap between modification zones. Test writing order (AC3 -> AC1 -> AC2) is reasonable — AC3 is simplest (exit code check), AC2 needs mock design for array expansion.

Plan specifies CHANGELOG + version bump last. Correct.

## R3: Technical risk assessment — PASS

### bash 3.2 compatibility — Verified

All three proposed constructs tested on this machine (bash 3.2.57):

| Construct | bash 3.2 | Verified |
|---|---|---|
| `[[ "$PR_NUMBER" =~ ^[0-9]+$ ]]` | Supported | Yes — tested with valid, invalid, injection, empty inputs |
| `image_paths+=("$path")` array append | Supported | Yes — tested with spaces in paths |
| `"${image_paths[@]}"` expansion | Supported | Yes — correctly preserves individual arguments |
| AWK `-v section_file="$VAR"` | AWK feature, not bash-dependent | Yes — tested with spaces in path |

### node argument order — No risk

`upload-image-to-github.mjs` uses `process.argv.slice(2)` — first arg is PR_URL, rest are image paths. Array expansion `"${image_paths[@]}"` preserves insertion order identical to the current string concatenation. No behavioral change.

### AWK `-v` with special characters — Verified

AWK `-v section_file="$SECTION_FILE"` correctly handles paths with spaces. The `$SECTION_FILE` is constructed from `$TMPDIR_BASE` (via `mktemp -d`) which produces paths without special characters in practice. The fix still improves safety for defense-in-depth.

## R4: Architecture consistency — PASS

| Aspect | Plan | Codebase Pattern | Match |
|---|---|---|---|
| Test file naming | `tests/test_pr_screenshot_security.bats` | `tests/test_*.bats` | Yes |
| Test setup pattern | `BATS_TEST_TMPDIR` + `setup()` fixtures | Same as `test_check_plugin_version.bats` | Yes |
| Error output | `>&2` with Usage format | Matches existing line 20 pattern | Yes |
| shellcheck compliance | Remove SC2086 disable | Eliminates a suppression — improves compliance | Yes |
| `.gitignore` style | Append patterns at end | Current file has no section headers, flat list | Yes |

## R5: Edge cases — PASS (with observation)

### Addressed by plan
- AC1: Special characters in `$SECTION_FILE` path — AWK `-v` handles this
- AC2: Spaces in image paths — array expansion handles this
- AC3: Empty string, non-integer, special characters — `[[ =~ ^[0-9]+$ ]]` rejects all

### Observation: empty array under `set -u`

On bash 3.2 with `set -euo pipefail`, expanding `"${image_paths[@]}"` on an **empty** array triggers "unbound variable" error. However, this is not a real risk because:

1. The guard at line 163 (`if [ ! -s "$UPLOAD_LIST" ]`) exits before reaching the array construction
2. The `while` loop at line 176 reads from `$UPLOAD_LIST` which is guaranteed non-empty at that point
3. Each UPLOAD_LIST entry has a non-empty `path` (set by `extract_image` which only writes on success)

Therefore `image_paths` will always have at least one element when expansion occurs. No plan change needed, but the implementer should be aware that adding a length guard (`if [ ${#image_paths[@]} -gt 0 ]`) before expansion would be a defensive option if the surrounding control flow ever changes.

### `.gitignore` pattern specificity

`*.local.*` will match files like `settings.local.json` (intended) but also `foo.local.bar.baz` (edge case, acceptable for gitignore). `*.secret` and `*.secrets` are suffix-only patterns — no false positive risk.

## R6: Test coverage — PASS

| AC | Test Layer | Coverage | Assessment |
|---|---|---|---|
| AC1: AWK injection | Unit (BATS) | AWK output correctness with normal and special-character paths | Adequate — tests the actual AWK transformation |
| AC2: image_paths array | Unit (BATS) | Array expansion preserves individual arguments including spaces | Adequate — verifies the fix purpose |
| AC3: PR number validation | Unit (BATS) | Exit code + error message for invalid inputs | Adequate — simplest to test, good edge case coverage |
| AC4: .gitignore patterns | Unit (BATS) | `git check-ignore` for each pattern | Adequate — `git check-ignore` is the authoritative check |

Test pattern follows `test_check_plugin_version.bats` conventions (`BATS_TEST_TMPDIR`, `setup()` fixtures). This is the correct approach for this repo.

**Note on AC1/AC2 testability:** The plan correctly identifies that AC1 and AC2 test the transformation logic in isolation (AWK output, argument passing) rather than requiring full script execution with `gh` CLI mocking. This is appropriate for security-focused unit tests.

## Version Bump

Current version: **1.5.0** (verified in `.claude-plugin/plugin.json`).

Plan does not specify a version number. This is a PATCH-level fix (security hardening, no behavioral change for valid inputs). Recommended bump: **1.5.0 -> 1.5.1**.

## Summary

| Criterion | Verdict | Notes |
|---|---|---|
| R1: File structure validity | PASS | All target files verified at correct line numbers |
| R2: Implementation order risks | PASS | All ACs independent, no dependency issues |
| R3: Technical risk assessment | PASS | bash 3.2 compatibility verified on this machine |
| R4: Architecture consistency | PASS | Follows existing test and code patterns |
| R5: Edge cases | PASS | Empty array edge case is safe due to existing guard |
| R6: Test coverage | PASS | All ACs covered with appropriate test strategies |

**Plan is ready for implementation.**
