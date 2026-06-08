#!/usr/bin/env bats
# @covers: scripts/ci/skill-e2e-guard.sh
# tests/test_skill_e2e_guard.bats
# BEHAVIORAL tests for the subscription-only CI guards. These EXECUTE the guard
# logic with poisoned inputs and assert exit codes, so inverting or gutting a
# guard turns the test red (a static grep of the workflow would not). (#243)

GUARD="scripts/ci/skill-e2e-guard.sh"

# All billing-redirect env vars the guard must reject. Kept in sync structurally
# by the "list matches the script" test below.
BILLING_VARS=(
  ANTHROPIC_API_KEY
  ANTHROPIC_AUTH_TOKEN
  ANTHROPIC_BASE_URL
  CLAUDE_CODE_USE_BEDROCK
  CLAUDE_CODE_USE_VERTEX
  ANTHROPIC_BEDROCK_BASE_URL
  ANTHROPIC_VERTEX_BASE_URL
)

setup() {
  [ -f "$GUARD" ] || skip "guard script missing: $GUARD"
}

clean_env() {
  # run the guard with every billing var explicitly unset
  local args=()
  local v
  for v in "${BILLING_VARS[@]}"; do args+=(-u "$v"); done
  env "${args[@]}" bash "$GUARD" "$@"
}

@test "billing-env: clean env exits 0" {
  run clean_env billing-env
  [ "$status" -eq 0 ]
}

@test "billing-env: EACH billing-redirect var trips a non-zero exit" {
  local v
  for v in "${BILLING_VARS[@]}"; do
    run env "$v=x" bash "$GUARD" billing-env
    if [ "$status" -eq 0 ]; then
      echo "guard did NOT reject $v (exit 0)"
      return 1
    fi
  done
}

@test "main-ref: refs/heads/main passes (exit 0)" {
  run bash "$GUARD" main-ref refs/heads/main
  [ "$status" -eq 0 ]
}

@test "main-ref: a non-main branch is rejected (non-zero)" {
  run bash "$GUARD" main-ref refs/heads/attacker
  [ "$status" -ne 0 ]
}

@test "main-ref: a tag ref is rejected (non-zero)" {
  run bash "$GUARD" main-ref refs/tags/v1.0.0
  [ "$status" -ne 0 ]
}

@test "main-ref: empty ref is rejected (non-zero)" {
  run bash "$GUARD" main-ref ""
  [ "$status" -ne 0 ]
}

@test "unknown subcommand exits non-zero (usage)" {
  run bash "$GUARD" bogus
  [ "$status" -ne 0 ]
}

@test "guard script lists at least the 7 known billing vars (no silent shrink)" {
  local v
  for v in "${BILLING_VARS[@]}"; do
    grep -qE "^\s*$v\b" "$GUARD" || { echo "missing $v in guard script"; return 1; }
  done
}
