# AC Review — Developer

**Issue:** #22 — bug: eval-guard.sh が main 側の SKILL.md 変更を誤検知する
**Reviewer:** Developer
**Date:** 2026-04-12

## Overall Assessment

**Verdict: PASS** — All four ACs are well-formed, technically sound, and cover the necessary scenarios. No AC changes required.

The proposed approach (three-dot diff + regex strengthening) is architecturally consistent, technically correct, and achievable in ~2 line changes as claimed.

## 1. Architecture Consistency

The hook design follows the existing pattern in `hooks/eval-guard.sh`:
- Read JSON input from stdin
- Extract command string
- Check conditions (branch, changed files, eval marker)
- Output JSON permit/deny

The proposed fix changes only the detection logic (lines 20 and 34), not the hook structure. This is the correct scope for a bug fix. The hook is registered in `.claude/settings.json` as a development-only PreToolUse hook on the `Bash` matcher.

## 2. Technical Feasibility

### Bug 1: Three-dot diff — CORRECT

**Current (buggy, line 34):** `git diff --name-only origin/main -- 'skills/*/SKILL.md'`
- Two-point diff comparing the working tree against `origin/main` tip
- If main advances after branch creation, all main-side changes appear in the diff

**Proposed:** `git diff --name-only origin/main...HEAD -- 'skills/*/SKILL.md'`
- Three-dot diff uses the merge-base as the comparison point
- Only shows changes introduced on the branch, not changes on main since divergence
- Standard Git idiom for "what did this branch change?" — same semantics as GitHub PR diffs

**Edge cases:**
- **Detached HEAD:** Already handled at line 27 — allows push if BRANCH is empty
- **Shallow clone:** `git merge-base` may fail in extremely shallow clones, but `2>/dev/null || echo ""` on line 34 handles errors gracefully (fail-open). Low risk since atdd-kit developers use full clones.
- **No `origin/main` remote:** Same error handling — returns empty, allowing push. Correct fail-open behavior.

### Bug 2: Regex strengthening — CORRECT

**Current (buggy, line 20):** `grep -q 'git push'`
- Matches "git push" anywhere in the command string, including inside arguments

**Proposed:** A regex matching `git push` as a command, not as a substring in arguments. Something like `grep -qE '(^|[;&|]\s*)git\s+push'` or equivalent. This is a single-line change on line 20.

## 3. Edge Case Coverage

### Covered by ACs
| AC | Scenario | Coverage |
|----|----------|----------|
| AC1 | Main-side SKILL.md changes after branch divergence (primary bug) | Primary regression test |
| AC2 | Branch-side SKILL.md changes still detected | Regression guard |
| AC3 | "git push" in command arguments | Secondary bug fix |
| AC4 | Chained commands with real git push | Regression guard for AC3 |

### Not covered but acceptable (no AC changes needed)

1. **Pipe commands** (e.g., `echo foo | git push`): Unusual for git push in practice. A well-designed regex for `&&`/`;`/`||` chains will naturally extend to `|`. Implementation detail, not worth a separate AC.

2. **`git` with flags before subcommand** (e.g., `git -c key=val push`): Extremely rare in Claude Code tool calls. Not worth an AC.

3. **Subshell/backtick forms** (e.g., `` `git push` `` or `$(git push)`): Doesn't occur in real usage. Not worth an AC.

4. **Multiple `git push` in one command** (e.g., `git push origin main && git push origin --tags`): Would be caught by the regex matching either occurrence. No issue.

## 4. Implementation Complexity

**Achievable in ~2 line changes:**

- **Line 34:** Change `git diff --name-only origin/main` to `git diff --name-only origin/main...HEAD` — one token addition.
- **Line 20:** Change `grep -q 'git push'` to `grep -qE '(^|[;&|]\s*)git\s+push'` or similar — one line replacement.

No new functions, no structural changes, no new dependencies. Minimal blast radius.

## 5. BATS Test Feasibility

Two approaches are available:

1. **Content-based assertions** (consistent with existing test patterns like `test_eval_framework.bats`): Verify the script contains `origin/main...HEAD` and an appropriate regex pattern.
2. **Functional tests**: Set up a temp git repo, pipe crafted JSON input to the script, check output JSON.

Either approach works. The ACs are fully testable.

## 6. Per-AC Feedback

| AC | Verdict | Notes |
|----|---------|-------|
| AC1 | PASS | Correctly tests the primary bug. Given/When/Then is precise and verifiable. |
| AC2 | PASS | Essential regression guard. Verifies the fix doesn't break core blocking behavior. |
| AC3 | PASS | Correctly tests the secondary bug. Example command is realistic. |
| AC4 | PASS | Good regression guard for AC3. Tests `&&` chaining which is the most common real-world pattern. |

## Conclusion

All four ACs are ready for the plan phase. No modifications required.
