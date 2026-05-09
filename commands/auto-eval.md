---
description: "Eval process -- runs skill evals for changed skills, compares against baseline, posts results as PR comment. No code edits."
---

# Skill Eval Process

Run evals for skills with changed `SKILL.md` since last baseline, compare against baseline, report regressions.

## Prerequisites

- `skill-creator:skill-creator` available (if not: "Install with `claude plugins add anthropics/skill-creator --scope project`" → STOP)
- `skills/*/evals/evals.json` must exist

## Constraints
- No code edits; no label changes

## Arguments

| Argument | Description |
|----------|-------------|
| (none) | Evaluate only skills with changed `SKILL.md` since last baseline |
| `--all` | Evaluate all skills that have `evals/evals.json` |

## Phase 1: Detect Changed Skills

1. `ls skills/`; for each dir check if `evals/evals.json` exists
2. Without `--all`: for each skill with evals, read `baseline.json` timestamp and run `git log --since="<timestamp>" -- skills/<skill>/SKILL.md`. Skip if unchanged. If no changes → "Nothing to evaluate." exit.
3. With `--all`: include all skills with `evals/evals.json`

## Phase 2: Run Evals

For each changed skill: read `evals.json`; run each eval via skill-creator against `atdd-kit:<skill>`; grade against `assertions` (PASS/FAIL); calculate `pass_rate` per eval and overall.

## Phase 3: Compare with Baseline

Read `baseline.json`; calculate delta (`current - baseline`). **Regression threshold: 10% drop** (delta <= -0.10).

## Phase 4: Report Results

### Console Output

```
Skill Eval Results

| Skill | Baseline | Current | Delta | Status |
|-------|----------|---------|-------|--------|
| discover | 100% | 100% | +0% | PASS |
| plan | 80% | 60% | -20% | REGRESSION |
```

### PR Comment (in PR context)

If PR number available (from environment or autopilot caller), post as PR comment via `gh pr comment`:

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

```markdown
#### plan -- Eval Breakdown

| Eval | Baseline | Current | Delta |
|------|----------|---------|-------|
| complex-feature | 100% | 60% | -40% |
| refactoring | 80% | 60% | -20% |
```

## Phase 5: Update Baseline

No regression: update `baseline.json`. Regression: do NOT update; warn and exit with regression flag.

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

- Per eval: up to 3 minutes
- Per skill total: up to 15 minutes
- Single eval timeout: mark FAIL, continue with remaining

## Exit Conditions

| Condition | Action |
|-----------|--------|
| No changed skills (and not `--all`) | Exit with "Nothing to evaluate", create marker |
| skill-creator not installed | Exit with install instructions (no marker) |
| All evals pass, no regression | Update baseline, create marker, exit success |
| Regression detected | Report details, do NOT update baseline, create marker, exit with warning |
