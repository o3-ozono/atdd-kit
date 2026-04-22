#!/usr/bin/env bash
# check_bats_covers.sh — validates that every BATS file has a @covers annotation
#
# Usage:
#   check_bats_covers.sh <file> [<file> ...]
#   check_bats_covers.sh (no args: scans tests/*.bats and addons/*/tests/*.bats)
#
# Exit codes:
#   0 — all files have valid @covers annotations
#   1 — one or more files are missing or have empty @covers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

violations=()

check_file() {
  local f="$1"
  local header
  header=$(head -n 5 "$f")
  local found_value=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^#[[:space:]]*@covers:[[:space:]]*(.*)$ ]]; then
      found_value="${BASH_REMATCH[1]}"
      # trim trailing whitespace
      found_value="${found_value%"${found_value##*[![:space:]]}"}"
      break
    fi
  done <<< "$header"

  if [[ -z "$found_value" ]]; then
    violations+=("$f")
  fi
}

# Collect files to check
files=()
if [[ $# -gt 0 ]]; then
  files=("$@")
else
  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(
    find "$REPO_ROOT/tests" -maxdepth 1 -name "*.bats" | sort
    find "$REPO_ROOT/addons" -path "*/tests/*.bats" 2>/dev/null | sort
  )
fi

for f in "${files[@]}"; do
  check_file "$f"
done

total=${#files[@]}

if [[ ${#violations[@]} -eq 0 ]]; then
  echo "OK: $total files"
  exit 0
else
  echo "FAIL: ${#violations[@]} of $total files missing valid @covers annotation:"
  for v in "${violations[@]}"; do
    echo "  $v"
  done
  exit 1
fi
