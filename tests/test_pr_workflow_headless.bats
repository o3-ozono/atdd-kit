#!/usr/bin/env bats
# @covers: scripts/test-skills-headless.sh
bats_require_minimum_version 1.5.0

# =============================================================================
# test_pr_workflow_headless.bats -- Static checks for CI integration
# Issue #72 / AC6
#
# Asserts that:
#   1. pr.yml declares a `headless` paths-filter output scoped to headless-only files.
#   2. pr.yml defines a `headless-replay` job gated by `needs.changes.outputs.headless`.
#   3. pr.yml runs all four replay-layer BATS files and does NOT invoke `claude`.
#   4. headless-live.yml exists, is workflow_dispatch-only, and uses ANTHROPIC_API_KEY.
#   5. ci-gate depends on headless-replay and fails on its failure.
# =============================================================================

REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
PR_YML="${REPO}/.github/workflows/pr.yml"
LIVE_YML="${REPO}/.github/workflows/headless-live.yml"

@test "AC6: pr.yml exposes a 'headless' paths-filter output" {
  [ -f "$PR_YML" ]
  grep -qE '^\s+headless:\s*\$\{\{\s*steps\.filter\.outputs\.headless\s*\}\}' "$PR_YML"
}

@test "AC6: pr.yml 'headless' filter is scoped to replay-relevant paths only" {
  # skills/** is load-bearing
  grep -qE "^\s+-\s+'skills/\*\*'" "$PR_YML"
  # runner + parser + assertion + scenario_loader paths present under filter
  grep -qE "scripts/test-skills-headless\.sh" "$PR_YML"
  grep -qE "lib/skill_transcript_parser\.sh" "$PR_YML"
  grep -qE "lib/skill_assertion\.sh" "$PR_YML"
  grep -qE "lib/scenario_loader\.sh" "$PR_YML"
  # fixture dir
  grep -qE "tests/fixtures/headless/\*\*" "$PR_YML"
  # Workflows themselves so edits to CI also re-run the job
  grep -qE "\.github/workflows/pr\.yml" "$PR_YML"
  grep -qE "\.github/workflows/headless-live\.yml" "$PR_YML"
}

@test "AC6: pr.yml 'headless' filter does NOT include broad dirs (hooks/agents/commands)" {
  # Extract the lines under the `headless:` filter block and make sure no
  # broad scopes were added (MVP should avoid flaky CI from unrelated edits).
  block=$(awk '/^\s+headless:/{f=1;next} f && /^\s{12}[a-z]/{exit} f{print}' "$PR_YML")
  if [ -z "$block" ]; then
    # Fallback: search in the whole filter section
    block=$(sed -n "/^\s\+headless:/,/^\s\{6,10\}[a-z][a-z_-]*:/p" "$PR_YML")
  fi
  ! printf '%s' "$block" | grep -qE "^\s+-\s+'hooks/\*\*'"
  ! printf '%s' "$block" | grep -qE "^\s+-\s+'agents/\*\*'"
  ! printf '%s' "$block" | grep -qE "^\s+-\s+'commands/\*\*'"
}

@test "AC6: pr.yml declares a 'headless-replay' job gated by outputs.headless" {
  grep -qE "^\s+headless-replay:\s*$" "$PR_YML"
  grep -qE "needs\.changes\.outputs\.headless\s*==\s*'true'" "$PR_YML"
}

@test "AC6: headless-replay runs all four replay-layer BATS files" {
  grep -qE "tests/test_skill_transcript_parser\.bats" "$PR_YML"
  grep -qE "tests/test_skill_assertion\.bats" "$PR_YML"
  grep -qE "tests/test_headless_runner\.bats" "$PR_YML"
  grep -qE "tests/test_headless_exit_codes\.bats" "$PR_YML"
}

@test "AC6: headless-replay does NOT invoke the claude binary" {
  # The replay layer is deterministic and must not spend tokens in PR CI.
  # Match only lines intended as shell invocations (exclude comments).
  ! grep -nE '^\s*[^#]*\bclaude\s+(-p|--output-format|--print)' "$PR_YML"
}

@test "AC6: ci-gate depends on headless-replay and fails on its failure" {
  grep -qE "needs:\s*\[.*headless-replay.*\]" "$PR_YML"
  grep -qE "needs\.headless-replay\.result\s*==\s*'failure'" "$PR_YML"
}

@test "AC6: headless-live.yml exists and is workflow_dispatch-only" {
  [ -f "$LIVE_YML" ]
  grep -qE "^\s*workflow_dispatch:" "$LIVE_YML"
  # Must not trigger on pull_request or push
  ! grep -qE "^\s*pull_request:" "$LIVE_YML"
  ! grep -qE "^\s*push:" "$LIVE_YML"
}

@test "AC6: headless-live.yml uses ANTHROPIC_API_KEY secret" {
  grep -qE "ANTHROPIC_API_KEY:\s*\\\$\{\{\s*secrets\.ANTHROPIC_API_KEY\s*\}\}" "$LIVE_YML"
}

@test "AC6: headless-live.yml runs the headless runner" {
  grep -qE "scripts/test-skills-headless\.sh" "$LIVE_YML"
}
