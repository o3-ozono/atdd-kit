#!/usr/bin/env bash
# fast-skill-description-lint.sh -- AC5 fast PASS sample
# Verifies that lint_skill_descriptions.sh exits 0 and reports WARN-only output.
# Fast layer: no fixture project, no skill chain.

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
LINTER="${REPO_ROOT}/scripts/lint_skill_descriptions.sh"

if [ ! -x "$LINTER" ]; then
  echo "Error: linter not found or not executable: $LINTER" >&2
  exit 3
fi

# Run linter on all skills
output=$(bash "$LINTER" 2>&1)
exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  echo "FAIL: linter exited with non-zero status $exit_code" >&2
  echo "$output" >&2
  exit 1
fi

# Verify linter produces output (at least one OK or VIOLATION line)
if [ -z "$output" ]; then
  echo "FAIL: linter produced no output" >&2
  exit 1
fi

echo "PASS: linter ran successfully (exit 0, WARN-only mode)"
echo "Output summary:"
ok_count=$(echo "$output" | grep -c "^OK " || true)
violation_count=$(echo "$output" | grep -c "^VIOLATION " || true)
echo "  OK: $ok_count, VIOLATIONS: $violation_count"
exit 0
