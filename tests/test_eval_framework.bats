#!/usr/bin/env bats

# =============================================================================
# Skill Eval Framework Tests
# Covers AC1 (change detection), AC3 (grading), AC4 (baseline comparison),
# AC5 (baseline update), AC6 (safe skip for evals-less skills)
# =============================================================================

# ---------------------------------------------------------------------------
# AC1: Changed skill detection
# ---------------------------------------------------------------------------

@test "auto-eval detects skills by checking SKILL.md changes" {
  grep -q 'SKILL.md' commands/auto-eval.md
}

@test "auto-eval uses git log to detect changes since baseline timestamp" {
  grep -q 'git log.*since\|git log.*timestamp' commands/auto-eval.md
}

@test "auto-eval supports --all flag to evaluate all skills" {
  grep -q '\-\-all' commands/auto-eval.md
}

@test "auto-eval exits with message when no skills changed" {
  grep -q 'Nothing to evaluate' commands/auto-eval.md
}

# ---------------------------------------------------------------------------
# AC3: Assertion-based grading
# ---------------------------------------------------------------------------

@test "auto-eval grades assertions as PASS or FAIL" {
  grep -q 'PASS.*FAIL\|PASS or FAIL\|PASS/FAIL' commands/auto-eval.md
}

@test "auto-eval calculates pass_rate per eval" {
  grep -q 'pass_rate' commands/auto-eval.md
}

# ---------------------------------------------------------------------------
# AC4: Baseline comparison and regression warning
# ---------------------------------------------------------------------------

@test "auto-eval reads baseline.json for comparison" {
  grep -q 'baseline.json' commands/auto-eval.md
}

@test "auto-eval uses 10% regression threshold" {
  grep -q '10%' commands/auto-eval.md
}

@test "auto-eval reports regression details with per-eval breakdown" {
  grep -q 'Regression' commands/auto-eval.md
}

@test "auto-eval posts results as PR comment" {
  grep -q 'gh pr comment\|PR comment' commands/auto-eval.md
}

@test "auto-eval result table includes Skill, Baseline, Current, Delta, Status columns" {
  grep -q 'Skill.*Baseline.*Current.*Delta.*Status' commands/auto-eval.md
}

# ---------------------------------------------------------------------------
# AC5: Baseline update
# ---------------------------------------------------------------------------

@test "auto-eval updates baseline when no regression detected" {
  grep -q 'Update.*baseline\|update.*baseline' commands/auto-eval.md
}

@test "auto-eval does NOT update baseline on regression" {
  grep -q 'NOT update baseline\|do NOT update\|Do NOT update' commands/auto-eval.md
}

# ---------------------------------------------------------------------------
# AC6: Safe skip for skills without evals
# ---------------------------------------------------------------------------

@test "auto-eval checks for evals.json existence before evaluating" {
  grep -q 'evals.json.*exist\|evals/evals.json' commands/auto-eval.md
}

@test "auto-eval skips skills without evals directory" {
  # The command should only evaluate skills that have evals/evals.json
  grep -q 'evals/evals.json' commands/auto-eval.md
}

# ---------------------------------------------------------------------------
# evals.json structure validation (discover)
# ---------------------------------------------------------------------------

@test "discover evals.json exists" {
  [ -f skills/discover/evals/evals.json ]
}

@test "discover evals.json has correct skill_name" {
  grep -q '"skill_name": "atdd-kit:discover"' skills/discover/evals/evals.json
}

@test "discover evals.json has at least 4 eval cases" {
  count=$(grep -c '"name":' skills/discover/evals/evals.json)
  [ "$count" -ge 4 ]
}

@test "discover evals.json has assertions for each eval" {
  grep -q '"assertions"' skills/discover/evals/evals.json
}

# ---------------------------------------------------------------------------
# baseline.json structure validation (discover)
# ---------------------------------------------------------------------------

@test "discover baseline.json exists" {
  [ -f skills/discover/evals/baseline.json ]
}

@test "discover baseline.json has timestamp field" {
  grep -q '"timestamp"' skills/discover/evals/baseline.json
}

@test "discover baseline.json has pass_rate field" {
  grep -q '"pass_rate"' skills/discover/evals/baseline.json
}

@test "discover baseline.json has results array with eval_name fields" {
  grep -q '"eval_name"' skills/discover/evals/baseline.json
}

@test "discover baseline.json results match evals.json eval names" {
  grep -q '"dev-feature"' skills/discover/evals/baseline.json
  grep -q '"bug-fix"' skills/discover/evals/baseline.json
  grep -q '"documentation"' skills/discover/evals/baseline.json
}

# ---------------------------------------------------------------------------
# Integration: autopilot includes eval option
# ---------------------------------------------------------------------------

@test "autopilot.md includes eval option" {
  grep -q 'eval' commands/autopilot.md
}

@test "autopilot.md maps eval to auto-eval command" {
  grep -q 'auto-eval' commands/autopilot.md
}

# ---------------------------------------------------------------------------
# Integration: auto-review triggers eval on skill changes
# ---------------------------------------------------------------------------

@test "autopilot QA phase reviews PR changes including skill files" {
  grep -qi 'QA\|PR.*review\|review.*PR' commands/autopilot.md
}

@test "autopilot references auto-eval for skill evaluation" {
  grep -q 'auto-eval' commands/autopilot.md
}

@test "autopilot utility mode includes eval" {
  grep -q 'eval' commands/autopilot.md
}

# ---------------------------------------------------------------------------
# Prerequisite: skill-creator dependency
# ---------------------------------------------------------------------------

@test "auto-eval requires skill-creator plugin" {
  grep -q 'skill-creator' commands/auto-eval.md
}

@test "auto-eval provides install instructions when skill-creator missing" {
  grep -q 'claude plugins add\|Install' commands/auto-eval.md
}
