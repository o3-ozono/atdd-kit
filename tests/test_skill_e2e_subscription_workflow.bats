#!/usr/bin/env bats
# tests/test_skill_e2e_subscription_workflow.bats
# Policy-critical invariants of .github/workflows/skill-e2e-subscription.yml
# (subscription-only Skill E2E CI). Locks the guards structurally so a future
# refactor cannot silently flip the billing policy, weaken the trust boundary,
# or reintroduce a script-injection sink while CI stays green. (Issue #243)

WF=".github/workflows/skill-e2e-subscription.yml"

setup() {
  [ -f "$WF" ] || skip "workflow file missing: $WF"
}

@test "trigger is workflow_dispatch only (no pull_request / push)" {
  grep -qE '^\s*workflow_dispatch:' "$WF"
  ! grep -qE '^\s*pull_request:' "$WF"
  ! grep -qE '^\s*push:' "$WF"
}

@test "runs on the dedicated self-hosted label atdd-kit-e2e" {
  grep -qE 'runs-on:.*self-hosted.*atdd-kit-e2e' "$WF"
}

@test "least-privilege permissions (contents: read)" {
  grep -qE '^\s*permissions:' "$WF"
  grep -qE 'contents:\s*read' "$WF"
}

@test "execution restricted to the main ref (no unreviewed branch on self-hosted)" {
  grep -qE 'refs/heads/main' "$WF"
}

@test "guard rejects all billing-redirect env (api key / auth token / bedrock / vertex)" {
  grep -q 'ANTHROPIC_API_KEY' "$WF"
  grep -q 'ANTHROPIC_AUTH_TOKEN' "$WF"
  grep -q 'CLAUDE_CODE_USE_BEDROCK' "$WF"
  grep -q 'CLAUDE_CODE_USE_VERTEX' "$WF"
}

@test "no billing-redirect env is ever SET in the workflow (only checked)" {
  ! grep -qE 'ANTHROPIC_API_KEY:\s*\$\{\{' "$WF"
  ! grep -qE 'ANTHROPIC_API_KEY=\S' "$WF"
  ! grep -qE 'secrets\.ANTHROPIC_API_KEY' "$WF"
}

@test "user inputs are env-ized, not interpolated into run: shell (no injection sink)" {
  ! grep -qE -- '--changed-files "\$\{\{' "$WF"
  grep -qE 'INPUT_CHANGED:\s*\$\{\{ *inputs\.changed_files' "$WF"
  grep -qE 'INPUT_ALL:\s*\$\{\{ *inputs\.all' "$WF"
}

@test "github.ref is env-ized (not interpolated into shell)" {
  grep -qE 'GH_REF:\s*\$\{\{ *github\.ref' "$WF"
  ! grep -qE '"\$\{\{ *github\.ref' "$WF"
}

@test "third-party actions are SHA-pinned (40-hex)" {
  run bash -c "grep -oE 'uses: [^ ]+@[^ ]+' '$WF' | grep -vE '@[0-9a-f]{40}' || true"
  [ -z "$output" ]
}

@test "job has a timeout" {
  grep -qE 'timeout-minutes:' "$WF"
}

@test "empty HEAD~1 diff is a no-op (exit 0), not a usage error" {
  grep -qE 'nothing to test' "$WF"
}
