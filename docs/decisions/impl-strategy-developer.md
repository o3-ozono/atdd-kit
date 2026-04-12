# Implementation Strategy: Issue #22

**Issue:** #22 — bug: eval-guard.sh が main 側の SKILL.md 変更を誤検知する
**Author:** Developer Agent
**Date:** 2026-04-12
**Prior Decision:** `docs/decisions/ac-review-developer.md`

## 1. File Structure and Modification Map

### Modified Files

| # | File | Nature of Change |
|---|------|------------------|
| F1 | `hooks/eval-guard.sh` | Line 34: two-dot diff → three-dot diff. Line 20: simple grep → regex for command detection. |
| F2 | `tests/test_eval_guard.bats` | **New file** — Functional BATS tests for all 4 ACs |
| F3 | `hooks/README.md` | Update eval-guard description to reflect three-dot diff |
| F4 | `CHANGELOG.md` | Add entry under `[Unreleased]` |
| F5 | `.claude-plugin/plugin.json` | Version bump (PATCH) |

### Unchanged Files (verify-only)

| File | Reason |
|------|--------|
| `.claude/settings.json` | Hook registration unchanged — same matcher, same command |
| `commands/auto-eval.md` | Eval logic unchanged — marker creation unaffected |
| `tests/test_eval_framework.bats` | Tests auto-eval command content, not eval-guard behavior |

## 2. Concrete Code Changes

### F1: `hooks/eval-guard.sh`

#### Change 1: Line 20 — Command detection regex

**Before:**
```bash
if ! echo "$COMMAND" | grep -q 'git push'; then
```

**After:**
```bash
if ! echo "$COMMAND" | grep -qE '(^|[;&|]+\s*)git\s+push'; then
```

**Rationale:**
- `(^|[;&|]+\s*)` — matches `git push` at start of command OR after chain operators (`&&`, `||`, `;`, `|`)
- `git\s+push` — requires whitespace between `git` and `push` (stricter than literal string)
- Does NOT match `git push` embedded inside quoted arguments (e.g., `git commit -m "remember to git push"`) because the `git push` substring is preceded by a space inside quotes, not by a chain operator or start-of-string in the top-level command structure

**Edge case analysis:**
- `git push origin main` — matches (`^git\s+push`) 
- `git add . && git push` — matches (`&&\s*git\s+push`)
- `git add . ; git push` — matches (`;\s*git\s+push`)
- `git commit -m "fix: remember to git push"` — does NOT match (preceded by space inside quotes, not a chain operator)
- `echo "git push" | some_tool` — does NOT match at the `echo` level, because `grep -qE` processes the full command string and `git push` after `echo "` is not preceded by a chain operator. However, the pipe `|` could match. Let me refine.

**Refined regex for line 20:**
```bash
if ! echo "$COMMAND" | grep -qE '(^|&&|;|\|\|)\s*git\s+push'; then
```

This explicitly matches only after `&&`, `;`, `||`, or at start-of-string. Single `|` (pipe) is excluded because `echo "foo" | git push` is not a real-world pattern for pushing, and the pipe's left side doesn't contain a push.

**Final decision:** Use `(^|&&|;|\|\|)\s*git\s+push\b`

- `^` — start of command string
- `&&` — AND chain
- `;` — sequential chain  
- `\|\|` — OR chain (escaped pipe)
- `\s*git\s+push\b` — optional whitespace, then `git push` as word boundary

```bash
if ! echo "$COMMAND" | grep -qE '(^|&&|;|\|\|)\s*git\s+push\b'; then
```

**Verification of AC3 scenario:**
- Input: `git commit -m "fix: remember to git push"`
- The substring `git push` is at position after `to `, not after `^`, `&&`, `;`, or `||`
- Result: NO match — command is not intercepted. CORRECT.

**Verification of AC4 scenario:**
- Input: `git add . && git push origin branch`
- The substring `git push` is after `&& `, which matches `&&\s*git\s+push`
- Result: MATCH — command is intercepted. CORRECT.

#### Change 2: Line 34 — Three-dot diff

**Before:**
```bash
CHANGED_SKILLS=$(git diff --name-only origin/main -- 'skills/*/SKILL.md' 2>/dev/null || echo "")
```

**After:**
```bash
CHANGED_SKILLS=$(git diff --name-only origin/main...HEAD -- 'skills/*/SKILL.md' 2>/dev/null || echo "")
```

**Rationale:**
- `origin/main...HEAD` uses the merge-base as the comparison point (three-dot diff)
- Only detects changes introduced on the current branch, not changes on main since divergence
- Same semantics as GitHub PR diff view
- The `2>/dev/null || echo ""` error handling remains — if merge-base computation fails (shallow clone, no remote), returns empty string (fail-open: allows push)

### F2: `tests/test_eval_guard.bats` (New File)

Functional tests that invoke `hooks/eval-guard.sh` with crafted JSON input and verify output.

#### Test Infrastructure

```bash
setup() {
  GUARD="hooks/eval-guard.sh"
  TEST_REPO="${BATS_TMPDIR}/eval-guard-repo-$$"
  
  # Create a minimal git repo to simulate branch scenarios
  git init "$TEST_REPO"
  cd "$TEST_REPO"
  git checkout -b main
  mkdir -p skills/test-skill
  echo "initial" > skills/test-skill/SKILL.md
  echo "readme" > README.md
  git add -A && git commit -m "initial"
  
  # Set up origin/main reference
  git branch -m main
  git checkout -b test-branch
}

teardown() {
  rm -rf "$TEST_REPO"
}

make_input() {
  local cmd="$1"
  printf '{"tool_name":"Bash","command":"%s"}' "$cmd"
}
```

**Note:** The `setup` creates a local repo with a `main` branch and a `test-branch`. For three-dot diff tests, we need to simulate `origin/main` — this requires either a bare remote or using `git update-ref refs/remotes/origin/main`. The latter is simpler:

```bash
# In setup, after creating test-branch:
git update-ref refs/remotes/origin/main main
```

#### Test Cases

| Test ID | AC | Scenario | Input Command | Expected |
|---------|-----|----------|---------------|----------|
| T1.1 | AC1 | Main-side SKILL.md change, branch has no skill changes | `git push origin test-branch` | `{}` (allow) |
| T1.2 | AC1 | Main-side SKILL.md change, branch only has README edit | `git push` | `{}` (allow) |
| T2.1 | AC2 | Branch introduces SKILL.md change, no eval marker | `git push` | deny with "SKILL.md changes detected" |
| T2.2 | AC2 | Branch introduces SKILL.md change, eval marker exists | `git push` | `{}` (allow) |
| T2.3 | AC2 | Deny message contains skill name | `git push` | deny message contains skill name |
| T3.1 | AC3 | "git push" in commit message argument | `git commit -m "remember to git push"` | `{}` (allow — not intercepted) |
| T3.2 | AC3 | "git push" in echo argument | `echo "run git push later"` | `{}` (allow — not intercepted) |
| T4.1 | AC4 | Chain command with git push | `git add . && git push origin branch` | intercepted (proceeds to diff check) |
| T4.2 | AC4 | Semicolon chain with git push | `git add . ; git push` | intercepted (proceeds to diff check) |
| T4.3 | AC4 | OR chain with git push | `git add . || git push` | intercepted (proceeds to diff check) |

**AC1 test setup detail (T1.1, T1.2):**
```bash
# Simulate main advancing after branch creation:
# 1. On test-branch, edit README only
echo "branch change" > README.md
git add README.md && git commit -m "readme edit"

# 2. Advance origin/main with a SKILL.md change
git update-ref refs/remotes/origin/main $(
  git stash -q 2>/dev/null
  git checkout main -q
  echo "main update" > skills/test-skill/SKILL.md
  git add -A && git commit -m "main skill update" -q
  git rev-parse HEAD
)
git checkout test-branch -q

# Now: origin/main has SKILL.md change, test-branch does NOT
# Two-dot diff would show SKILL.md (bug)
# Three-dot diff should NOT show SKILL.md (fix)
```

**AC2 test setup detail (T2.1):**
```bash
# On test-branch, modify SKILL.md
echo "branch skill change" > skills/test-skill/SKILL.md
git add -A && git commit -m "skill edit on branch"
# Three-dot diff SHOULD show SKILL.md (correct detection)
```

### F3: `hooks/README.md`

Update the eval-guard.sh description:

**Before (line 33):**
```
2. If the command contains `git push`, checks for SKILL.md changes vs origin/main
```

**After:**
```
2. If the command is a `git push` (not in arguments), checks for SKILL.md changes on this branch vs merge-base with origin/main
```

### F4: `CHANGELOG.md`

```markdown
## [Unreleased]

### Fixed
- eval-guard.sh: use three-dot diff (`origin/main...HEAD`) to detect only branch-introduced SKILL.md changes, preventing false positives when main advances (#22)
- eval-guard.sh: strengthen git push detection regex to avoid false positives from "git push" in command arguments (#22)
```

### F5: `.claude-plugin/plugin.json`

PATCH bump — this is a bug fix with no behavioral contract change for the hook's external interface.

Current version needs to be read at implementation time.

## 3. Implementation Sequence (Test-First)

### Phase 1: Red — Write Failing Tests

**Step 1.1:** Create `tests/test_eval_guard.bats` with all test cases (T1.1-T4.3).

Run tests to confirm they fail against the current buggy code:
- T1.1, T1.2 should FAIL (current two-dot diff detects main-side changes)
- T3.1, T3.2 should FAIL (current grep matches "git push" in arguments)
- T2.1, T2.2, T2.3, T4.1, T4.2, T4.3 should PASS (existing correct behavior)

**Verification:** `bats tests/test_eval_guard.bats` — exactly T1.x and T3.x fail.

### Phase 2: Green — Fix the Bugs

**Step 2.1:** Fix line 34 (three-dot diff) — this fixes T1.1, T1.2.

**Step 2.2:** Fix line 20 (regex) — this fixes T3.1, T3.2.

**Verification:** `bats tests/test_eval_guard.bats` — all tests pass.

### Phase 3: Housekeeping

**Step 3.1:** Update `hooks/README.md` (F3).

**Step 3.2:** Update `CHANGELOG.md` (F4).

**Step 3.3:** Bump version in `.claude-plugin/plugin.json` (F5).

**Step 3.4:** Run full test suite: `bats tests/` to verify no regressions.

## 4. Dependencies

```
F2 (tests) ← F1 (guard fix) ← F3 (README) ← F4 (CHANGELOG) + F5 (version)
   write first    fix second     then docs      finally housekeeping
```

- F2 has no dependencies — tests are written against the expected behavior
- F1 depends on F2 being written first (test-first methodology)
- F3, F4, F5 are independent of each other but depend on F1 being complete

## 5. Technical Risks and Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| R1 | BATS test git repo setup is fragile | Medium | Medium | Use `BATS_TMPDIR` for isolation. Clean up in `teardown`. Use `git update-ref` instead of a real remote. |
| R2 | Regex doesn't cover all chain operators | Low | Low | AC4 specifies `&&` as the test case. Regex covers `&&`, `;`, `\|\|`. Pipe `\|` intentionally excluded — `echo "x" \| git push` is not real usage. |
| R3 | `\b` word boundary in grep -E | Low | Medium | `\b` is supported by GNU grep and BSD grep (macOS). Verify in CI. Fallback: use `git\s+push(\s\|$)` if `\b` is unsupported. |
| R4 | Three-dot diff with unrelated histories | Very Low | Low | `2>/dev/null \|\| echo ""` handles merge-base failure. Fail-open. |
| R5 | `sed` command on line 17 fails to extract command from complex JSON | Pre-existing | — | Out of scope for this bug fix. The `sed` extraction is simplistic but works for Claude Code's Bash tool JSON format. |

## 6. Per-AC Implementation Mapping

| AC | Phase | Step | File | Change |
|----|-------|------|------|--------|
| AC1 | 1→2 | 1.1→2.1 | F2→F1 | Tests T1.1-T1.2 → Line 34 three-dot diff |
| AC2 | 1→verify | 1.1 | F2 | Tests T2.1-T2.3 (should pass with existing code) |
| AC3 | 1→2 | 1.1→2.2 | F2→F1 | Tests T3.1-T3.2 → Line 20 regex |
| AC4 | 1→verify | 1.1 | F2 | Tests T4.1-T4.3 (should pass with existing code, verify with new regex) |
