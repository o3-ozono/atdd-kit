#!/usr/bin/env bats
# @covers: .github/workflows/pr.yml
# @covers: .github/workflows/skill-e2e-live.yml
# Static checks for the skill-e2e-test CI integration (#179 Step G1 / #208).
#
# Design (option B, per #222 "CI is supplementary, evidence is local-mandatory"
# and the repo having no ANTHROPIC_API_KEY secret configured):
#   - pr.yml gains a `skill-e2e-test` job that runs run-skill-e2e.sh in
#     --dry-run mode (resolve targets + structural check, NO claude, zero tokens,
#     no secret required), gated to skill/test/script changes.
#   - Real live execution lives in skill-e2e-live.yml (workflow_dispatch only,
#     uses ANTHROPIC_API_KEY), mirroring headless-live.yml.
#   - ci-gate depends on skill-e2e-test and fails on its failure.
#   - log artifact (tests/e2e/.logs/*.log) is uploaded.

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
PR_YML="${REPO}/.github/workflows/pr.yml"
LIVE_YML="${REPO}/.github/workflows/skill-e2e-live.yml"

@test "G1: pr.yml declares a 'skill-e2e-test' job" {
  [ -f "$PR_YML" ]
  grep -qE "^\s+skill-e2e-test:\s*$" "$PR_YML"
}

@test "G1: skill-e2e-test is gated on skills/tests/config changes" {
  grep -qE "needs\.changes\.outputs\.(skills|tests|config)\s*==\s*'true'" "$PR_YML"
}

@test "G1: skill-e2e-test runs run-skill-e2e.sh in --dry-run (no token spend)" {
  grep -qE "scripts/run-skill-e2e\.sh" "$PR_YML"
  grep -qE "run-skill-e2e\.sh.*--dry-run|--dry-run" "$PR_YML"
}

@test "G1: skill-e2e-test passes --changed-files derived from the PR" {
  grep -qE "\-\-changed-files" "$PR_YML"
}

@test "G1: skill-e2e-test does NOT invoke the claude binary (zero tokens in PR CI)" {
  ! grep -nE '^\s*[^#]*\bclaude\s+(-p|--output-format|--print)' "$PR_YML"
}

@test "G1: skill-e2e-test uploads the e2e log artifact" {
  grep -qE "tests/e2e/\.logs" "$PR_YML"
  grep -qE "actions/upload-artifact" "$PR_YML"
}

@test "G1: ci-gate depends on skill-e2e-test and fails on its failure" {
  grep -qE "needs:\s*\[.*skill-e2e-test.*\]" "$PR_YML"
  grep -qE "needs\.skill-e2e-test\.result\s*==\s*'failure'" "$PR_YML"
}

@test "G1: evals job is fully removed from pr.yml" {
  ! grep -qiE "eval" "$PR_YML"
}

# --- Live workflow (workflow_dispatch, secret-gated) ----------------------

@test "G1: skill-e2e-live.yml exists and is workflow_dispatch-only" {
  [ -f "$LIVE_YML" ]
  grep -qE "^\s*workflow_dispatch:" "$LIVE_YML"
  ! grep -qE "^\s*pull_request:" "$LIVE_YML"
  ! grep -qE "^\s*push:" "$LIVE_YML"
}

@test "G1: skill-e2e-live.yml uses ANTHROPIC_API_KEY secret" {
  grep -qE "ANTHROPIC_API_KEY:\s*\\\$\{\{\s*secrets\.ANTHROPIC_API_KEY\s*\}\}" "$LIVE_YML"
}

@test "G1: skill-e2e-live.yml runs the skill-e2e runner against all skills" {
  grep -qE "scripts/run-skill-e2e\.sh" "$LIVE_YML"
  grep -qE "\-\-all" "$LIVE_YML"
}
