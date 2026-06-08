#!/usr/bin/env bash
# scripts/ci/skill-e2e-guard.sh
# Subscription-only Skill E2E CI guards — single source of truth.
#
# The billing-redirect env blocklist and the main-ref trust boundary live here
# (not inline in the workflow) so that:
#   1. the list is defined once (no Guard/bats/docs drift), and
#   2. the guards are BEHAVIORALLY testable — tests/test_skill_e2e_guard.bats
#      runs this script with poisoned inputs and asserts a non-zero exit, so
#      inverting or gutting a guard turns the test red (a static grep would not).
#
# Usage:
#   skill-e2e-guard.sh billing-env          # exit 1 if any billing-redirect env is set
#   skill-e2e-guard.sh main-ref <github.ref> # exit 1 unless ref == refs/heads/main
#
# NOTE on the trust model: on workflow_dispatch the whole repo (this script
# included) comes from the dispatched ref, so anyone with WRITE access can edit
# these guards. They are SAFETY RAILS against accidental misuse, not a boundary
# against a malicious write-collaborator — write access is the real trust
# boundary (see docs/testing-skills.md (j) accept-risk).
set -euo pipefail

# Canonical list of env vars that redirect Claude billing away from the
# macOS-Keychain subscription credential to metered API / cloud billing.
BILLING_ENV_VARS=(
  ANTHROPIC_API_KEY
  ANTHROPIC_AUTH_TOKEN
  ANTHROPIC_BASE_URL
  CLAUDE_CODE_USE_BEDROCK
  CLAUDE_CODE_USE_VERTEX
  ANTHROPIC_BEDROCK_BASE_URL
  ANTHROPIC_VERTEX_BASE_URL
)

guard_billing_env() {
  local v
  for v in "${BILLING_ENV_VARS[@]}"; do
    if [ -n "$(printenv "$v" 2>/dev/null || true)" ]; then
      echo "::error::$v is set — subscription-only policy violation. Unset it on the runner." >&2
      return 1
    fi
  done
  echo "OK: no billing-redirect env present (${#BILLING_ENV_VARS[@]} checked)"
}

guard_main_ref() {
  local ref="${1:-}"
  if [ "$ref" != "refs/heads/main" ]; then
    echo "::error::This workflow runs only on refs/heads/main (got: ${ref:-<empty>}). 未レビュー ref は不可。" >&2
    return 1
  fi
  echo "OK: ref=$ref"
}

main() {
  case "${1:-}" in
    billing-env) guard_billing_env ;;
    main-ref)    guard_main_ref "${2:-}" ;;
    *)
      echo "usage: $0 {billing-env | main-ref <github.ref>}" >&2
      exit 2
      ;;
  esac
}

main "$@"
