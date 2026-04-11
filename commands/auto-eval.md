---
description: "Eval process -- runs skill evals for changed skills, compares against baseline, posts results as PR comment. No code edits."
---

# Skill Eval Process

Run evals for skills whose `SKILL.md` has changed since the last baseline, compare results against baseline, and report regressions.

## Prerequisites

- **skill-creator plugin required:** Check that the `skill-creator:skill-creator` skill is available. If not, stop and tell the user: "skill-creator plugin is required. Install it with: `claude plugins add anthropics/skill-creator --scope project`"
- `skills/*/evals/evals.json` must exist for a skill to be evaluated

## Constraints
- **No code edits** -- eval and report only
- **No label changes** -- notification only

## Arguments

| Argument | Description |
|----------|-------------|
| (none) | Evaluate only skills with changed `SKILL.md` since last baseline |
| `--all` | Evaluate all skills that have `evals/evals.json` |

## Phase 1: Detect Changed Skills

1. List all skill directories: `ls skills/`
2. For each skill directory, check if `skills/<skill>/evals/evals.json` exists
3. If `--all` flag is NOT set:
   - For each skill with evals, check if `SKILL.md` has changed:
     - If `skills/<skill>/evals/baseline.json` exists, read its `timestamp`
     - Run `git log --since="<timestamp>" --oneline -- skills/<skill>/SKILL.md`
     - If no commits found, skip this skill (unchanged)
   - If no skills have changes, output "No skill changes detected. Nothing to evaluate." and exit
4. If `--all` flag IS set: include all skills that have `evals/evals.json`

## Phase 2: Run Evals

For each changed skill:

1. Read `skills/<skill>/evals/evals.json`
2. For each eval in the `evals` array:
   - Use skill-creator's eval mechanism to run the skill against the eval prompt
   - The skill under test is `atdd-kit:<skill>` (from `evals.json` `skill_name` field)
   - Collect the output for grading
3. Grade each output against the eval's `assertions` array
   - Each assertion is PASS or FAIL
   - Calculate `pass_rate` per eval: `passed / total`
   - Calculate overall `pass_rate` for the skill: `total_passed / total_assertions`

## Phase 3: Compare with Baseline

For each evaluated skill:

1. Read `skills/<skill>/evals/baseline.json` (if it exists)
2. Compare current `pass_rate` with baseline `pass_rate`
3. Calculate delta: `current - baseline`
4. **Regression threshold: 10% drop** -- if delta <= -0.10, flag as regression

## Phase 4: Report Results

### Console Output

Print a summary table:

```
Skill Eval Results

| Skill | Baseline | Current | Delta | Status |
|-------|----------|---------|-------|--------|
| discover | 100% | 100% | +0% | PASS |
| plan | 80% | 60% | -20% | REGRESSION |
```

### PR Comment (when running in PR context)

If a PR number is available (from environment or autopilot (QA) caller), post results as PR comment using `gh pr comment`:

```markdown
## Skill Eval Results

| Skill | Baseline | Current | Delta | Status |
|-------|----------|---------|-------|--------|
| discover | 100% | 100% | +0% | PASS |
| plan | 80% | 60% | -20% | REGRESSION |

### Regression Details

**plan**: pass_rate dropped from 80% to 60% (-20%)
- Eval "complex-feature": B3 (FAIL) -- All ACs in Given/When/Then format
- Eval "refactoring": B5 (FAIL) -- Deliverables header present
```

### Per-eval Breakdown (on regression)

When regression is detected, include per-eval details:

```markdown
#### plan -- Eval Breakdown

| Eval | Baseline | Current | Delta |
|------|----------|---------|-------|
| complex-feature | 100% | 60% | -40% |
| refactoring | 80% | 60% | -20% |
```

## Phase 5: Update Baseline

- **If no regression detected:** Update `skills/<skill>/evals/baseline.json` with current results
- **If regression detected:** Do NOT update baseline. Output warning and exit with regression flag

### baseline.json Format

```json
{
  "timestamp": "2026-04-03T12:00:00Z",
  "skill_name": "atdd-kit:discover",
  "pass_rate": 1.0,
  "results": [
    {"eval_name": "dev-feature", "pass_rate": 1.0, "passed": 7, "total": 7},
    {"eval_name": "bug-fix", "pass_rate": 1.0, "passed": 5, "total": 5},
    {"eval_name": "documentation", "pass_rate": 1.0, "passed": 4, "total": 4}
  ]
}
```

## Timeout Guidance

- Each eval prompt execution: allow up to 3 minutes
- Total eval run per skill: allow up to 15 minutes
- If a single eval times out, mark it as FAIL and continue with remaining evals

## Phase 6: Create Eval Evidence Marker

After eval completes (regardless of pass/fail), create an evidence marker so the `eval-guard` hook allows `git push`:

```bash
BRANCH=$(git branch --show-current | tr '/' '-')
touch "/tmp/atdd-kit-eval-ran-${BRANCH}"
```

This marker is checked by the PreToolUse `eval-guard.sh` hook. Without it, `git push` is blocked when SKILL.md changes are detected.

## Exit Conditions

| Condition | Action |
|-----------|--------|
| No changed skills (and not `--all`) | Exit with "Nothing to evaluate", create marker |
| skill-creator not installed | Exit with install instructions (no marker) |
| All evals pass, no regression | Update baseline, create marker, exit success |
| Regression detected | Report details, do NOT update baseline, create marker, exit with warning |
