#!/usr/bin/env bash
# fast-intentional-fail.sh -- AC5 fast FAIL (negative) sample
# Intentionally asserts a string that will never appear in any output.
# Purpose: proves that the test framework correctly detects assertion failures.
# Skill E2E Test (single-turn): no fixture project, no skill chain.

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
TEST_HELPERS="${SCRIPT_DIR}/../test-helpers.sh"

source "$TEST_HELPERS"

run_claude "test prompt"

# This assertion is intentionally designed to fail — the string below
# will never appear in any real or stub claude output.
assert_contains "INTENTIONAL_FAIL_STRING_THAT_WILL_NEVER_APPEAR_XYZ_12345"
