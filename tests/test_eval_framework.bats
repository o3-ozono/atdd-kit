#!/usr/bin/env bats
# @covers: scripts/**
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
# Prerequisite: skill-creator dependency
# ---------------------------------------------------------------------------

@test "auto-eval requires skill-creator plugin" {
  grep -q 'skill-creator' commands/auto-eval.md
}

@test "auto-eval provides install instructions when skill-creator missing" {
  grep -q 'claude plugins add\|Install' commands/auto-eval.md
}
