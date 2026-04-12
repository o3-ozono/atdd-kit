#!/usr/bin/env bats

# Test file for Issue #26: security hardening for pr-screenshot-table.sh and .gitignore

SCRIPT="scripts/pr-screenshot-table.sh"

# ---------------------------------------------------------------------------
# AC3: PR number input validation
# ---------------------------------------------------------------------------

@test "AC3: valid integer PR number is accepted (does not exit with validation error)" {
  # We can only test the validation line itself, not the full script
  # (which requires gh CLI). Extract and test the validation logic.
  run bash -c '
    set -euo pipefail
    PR_NUMBER="123"
    if [[ ! "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
      echo "Error: PR_NUMBER must be a positive integer, got: $PR_NUMBER" >&2
      exit 1
    fi
    echo "valid"
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == "valid" ]]
}

@test "AC3: alphabetic PR number is rejected with exit 1" {
  run bash -c '
    set -euo pipefail
    PR_NUMBER="abc"
    if [[ ! "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
      echo "Error: PR_NUMBER must be a positive integer, got: $PR_NUMBER" >&2
      exit 1
    fi
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"must be a positive integer"* ]]
}

@test "AC3: injection attempt in PR number is rejected" {
  run bash -c '
    set -euo pipefail
    PR_NUMBER="12;ls"
    if [[ ! "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
      echo "Error: PR_NUMBER must be a positive integer, got: $PR_NUMBER" >&2
      exit 1
    fi
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"must be a positive integer"* ]]
}

@test "AC3: empty PR number is rejected" {
  run bash -c '
    set -euo pipefail
    PR_NUMBER=""
    if [[ ! "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
      echo "Error: PR_NUMBER must be a positive integer, got: $PR_NUMBER" >&2
      exit 1
    fi
  '
  [[ "$status" -eq 1 ]]
}

@test "AC3: pr-screenshot-table.sh contains PR_NUMBER validation regex" {
  grep -q '\[\[.*\$PR_NUMBER.*=~.*\^\[0-9\]' "$SCRIPT"
}
