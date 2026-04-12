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

# ---------------------------------------------------------------------------
# AC1: AWK code injection prevention
# ---------------------------------------------------------------------------

@test "AC1: AWK section replacement produces correct output with normal path" {
  section_file="${BATS_TEST_TMPDIR}/section.txt"
  printf '## Screenshots\nNEW CONTENT\n' > "$section_file"

  input="## Screenshots
old content line 1
old content line 2
## Next Section
keep this"

  result="$(echo "$input" | awk -v section_file="$section_file" '
    /^## Screenshots/ { skip=1; while ((getline line < section_file) > 0) print line; next }
    /^## / && skip { skip=0 }
    !skip { print }
  ')"

  [[ "$result" == *"NEW CONTENT"* ]]
  [[ "$result" == *"## Next Section"* ]]
  [[ "$result" == *"keep this"* ]]
  [[ "$result" != *"old content"* ]]
}

@test "AC1: AWK section replacement works with spaces in file path" {
  section_file="${BATS_TEST_TMPDIR}/path with spaces/section.txt"
  mkdir -p "$(dirname "$section_file")"
  printf '## Screenshots\nSPACE PATH CONTENT\n' > "$section_file"

  input="## Screenshots
old
## Other"

  result="$(echo "$input" | awk -v section_file="$section_file" '
    /^## Screenshots/ { skip=1; while ((getline line < section_file) > 0) print line; next }
    /^## / && skip { skip=0 }
    !skip { print }
  ')"

  [[ "$result" == *"SPACE PATH CONTENT"* ]]
  [[ "$result" == *"## Other"* ]]
}

@test "AC1: pr-screenshot-table.sh uses awk -v for SECTION_FILE (no shell expansion)" {
  # Must use awk -v section_file= pattern
  grep -q 'awk -v section_file=' "$SCRIPT"
  # Must NOT use the old unsafe shell expansion pattern
  ! grep -q "getline line < \"'\"" "$SCRIPT"
}

# ---------------------------------------------------------------------------
# AC2: Safe image_paths expansion
# ---------------------------------------------------------------------------

@test "AC2: bash array preserves paths with spaces as individual arguments" {
  # Simulate the array-based approach
  run bash -c '
    set -euo pipefail
    image_paths=()
    image_paths+=("/tmp/path with spaces/img1.png")
    image_paths+=("/tmp/normal/img2.png")

    # Count arguments — each path should be one argument
    count=0
    for arg in "${image_paths[@]}"; do
      count=$((count + 1))
    done
    echo "$count"
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == "2" ]]
}

@test "AC2: single image path is correctly passed as one argument" {
  run bash -c '
    set -euo pipefail
    image_paths=()
    image_paths+=("/tmp/single image.png")

    count=0
    for arg in "${image_paths[@]}"; do
      count=$((count + 1))
    done
    echo "$count"
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == "1" ]]
}

@test "AC2: pr-screenshot-table.sh uses array for image_paths (not string concatenation)" {
  # Must use array declaration
  grep -q 'image_paths=()' "$SCRIPT"
  # Must use array append
  grep -q 'image_paths+=(' "$SCRIPT"
  # Must use array expansion
  grep -q '"${image_paths\[@\]}"' "$SCRIPT"
}

@test "AC2: SC2086 disable comment is removed from pr-screenshot-table.sh" {
  ! grep -q 'shellcheck disable=SC2086' "$SCRIPT"
}
