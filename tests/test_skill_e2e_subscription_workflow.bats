#!/usr/bin/env bats
# @covers: .github/workflows/skill-e2e-subscription.yml
# tests/test_skill_e2e_subscription_workflow.bats
# STRUCTURAL invariants of the subscription-only Skill E2E workflow.
# The guard BEHAVIOR (billing-env rejection, main-ref boundary) is verified
# separately and behaviorally in tests/test_skill_e2e_guard.bats; here we lock
# the workflow wiring (triggers, least-privilege, env-ization, SHA-pin, no-op,
# and that it actually delegates to the tested guard script). (#243)

WF=".github/workflows/skill-e2e-subscription.yml"

setup() {
  [ -f "$WF" ] || skip "workflow file missing: $WF"
}

@test "trigger is workflow_dispatch only (no pull_request / push / schedule / workflow_call)" {
  grep -qE '^\s*workflow_dispatch:' "$WF"
  ! grep -qE '^\s*pull_request(_target)?:' "$WF"
  ! grep -qE '^\s*push:' "$WF"
  ! grep -qE '^\s*schedule:' "$WF"
  ! grep -qE '^\s*workflow_call:' "$WF"
}

@test "runs on the dedicated self-hosted label atdd-kit-e2e" {
  grep -qE 'runs-on:.*self-hosted.*atdd-kit-e2e' "$WF"
}

@test "least-privilege: contents:read and NO write escalation anywhere" {
  grep -qE 'contents:\s*read' "$WF"
  # no permission of any scope is granted write
  ! grep -qE '^\s*[a-z-]+:\s*write\b' "$WF"
  ! grep -qE 'permissions:\s*write-all' "$WF"
}

@test "delegates guards to the behaviorally-tested guard script" {
  grep -qE 'skill-e2e-guard\.sh main-ref' "$WF"
  grep -qE 'skill-e2e-guard\.sh billing-env' "$WF"
}

@test "no billing-redirect secret/env is ever SET in the workflow" {
  ! grep -qE 'ANTHROPIC_API_KEY:\s*\$\{\{' "$WF"
  ! grep -qE 'ANTHROPIC_API_KEY=\S' "$WF"
  ! grep -qE 'secrets\.ANTHROPIC' "$WF"
}

@test "user inputs are env-ized, not interpolated into run: shell (no injection sink)" {
  # no \${{ ... }} interpolation appears on any command inside a run: block.
  # inputs/refs must reach bash via env: only.
  ! grep -qE -- '--changed-files "\$\{\{' "$WF"
  ! grep -qE '"\$\{\{ *github\.ref' "$WF"
  grep -qE 'INPUT_CHANGED:\s*\$\{\{ *inputs\.changed_files' "$WF"
  grep -qE 'INPUT_ALL:\s*\$\{\{ *inputs\.all' "$WF"
  grep -qE 'GH_REF:\s*\$\{\{ *github\.ref' "$WF"
}

@test "third-party actions are SHA-pinned (exactly 40 hex, anchored)" {
  # extract the @ref of every external 'uses:' and require a 40-hex commit SHA
  while IFS= read -r ref; do
    [[ "$ref" =~ ^[0-9a-f]{40}$ ]] || { echo "not SHA-pinned: '$ref'"; return 1; }
  done < <(grep -oE 'uses: [^ ]+@[^ ]+' "$WF" | sed -E 's/.*@//')
}

@test "job has a timeout" {
  grep -qE 'timeout-minutes:' "$WF"
}

@test "empty HEAD~1 diff is a no-op (exit 0), not a usage error" {
  grep -qE 'nothing to test' "$WF"
  grep -qE 'exit 0' "$WF"
}
