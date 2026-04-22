#!/usr/bin/env bash
# fast-discover.sh -- AC1: fast L4 test for discover skill meta-knowledge
# Verifies that Claude can read discover's required keywords and ordering.
# Fast layer: single-turn claude -p, no fixture project, no skill chain.

set -u
set -o pipefail

: "${SKILL_TEST_TMPDIR:?SKILL_TEST_TMPDIR must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
HELPERS="${SCRIPT_DIR}/../test-helpers.sh"
FIXTURE="${SCRIPT_DIR}/../fixtures/discover-keywords.txt"

if [ ! -f "$HELPERS" ]; then
  echo "Error: test-helpers.sh not found: $HELPERS" >&2
  exit 3
fi
if [ ! -f "$FIXTURE" ]; then
  echo "Error: keyword fixture not found: $FIXTURE" >&2
  exit 3
fi

# shellcheck source=../test-helpers.sh
source "$HELPERS"

DISCOVER_SKILL="${REPO_ROOT}/skills/discover/SKILL.md"
if [ ! -f "$DISCOVER_SKILL" ]; then
  echo "Error: discover SKILL.md not found: $DISCOVER_SKILL" >&2
  exit 3
fi

CLAUDE_BIN=$(_claude_bin)
if [ -z "$CLAUDE_BIN" ]; then
  echo "Error: claude binary not found; set SKILL_TEST_CLAUDE_BIN or install claude" >&2
  exit 3
fi

TIMEOUT_SECS="${SKILL_TEST_TIMEOUT_SECS:-120}"

# Resolve timeout command: GNU timeout (Linux) or perl fallback (macOS)
_timeout_cmd() {
  if command -v timeout > /dev/null 2>&1; then
    echo "timeout $TIMEOUT_SECS"
  elif command -v gtimeout > /dev/null 2>&1; then
    echo "gtimeout $TIMEOUT_SECS"
  else
    echo ""
  fi
}

# Read keyword list from fixture (one keyword per line, blank lines ignored)
# Use while-read for bash 3 compat (macOS default /bin/bash is v3)
KEYWORDS=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  KEYWORDS+=("$line")
done < <(grep -v '^[[:space:]]*$' "$FIXTURE")

if [ "${#KEYWORDS[@]}" -eq 0 ]; then
  echo "Error: keyword fixture is empty: $FIXTURE" >&2
  exit 3
fi

PROMPT="You are reading the atdd-kit discover skill at ${DISCOVER_SKILL}. \
List the key concepts and terms that appear in that skill, in the order they are introduced. \
Include: what to run first, gate conditions, exploration steps, deliverable types, \
quality checks, output format, and transition target skill."

echo "Running fast discover test (timeout=${TIMEOUT_SECS}s)..."

# Build timeout prefix if available
TIMEOUT_PREFIX=$(_timeout_cmd)

# Run with optional timeout and --max-turns 1
if [ -n "$TIMEOUT_PREFIX" ]; then
  # shellcheck disable=SC2086
  OUTPUT=$(${TIMEOUT_PREFIX} "$CLAUDE_BIN" -p "$PROMPT" \
    --max-turns 3 \
    --permission-mode bypassPermissions \
    2>/dev/null) || {
    exit_code=$?
    if [ "$exit_code" -eq 124 ]; then
      echo "FAIL: timeout after ${TIMEOUT_SECS}s" >&2
      exit 1
    fi
    echo "FAIL: claude exited with code $exit_code" >&2
    exit 1
  }
else
  OUTPUT=$("$CLAUDE_BIN" -p "$PROMPT" \
    --max-turns 3 \
    --permission-mode bypassPermissions \
    2>/dev/null) || {
    echo "FAIL: claude exited with code $?" >&2
    exit 1
  }
fi

if [ -z "$OUTPUT" ]; then
  echo "FAIL: claude produced no output" >&2
  exit 1
fi

# assert_contains for each keyword (regex to handle case/spacing variants)
fail_count=0
for kw in "${KEYWORDS[@]}"; do
  if ! echo "$OUTPUT" | grep -qiE "$kw"; then
    echo "FAIL: keyword not found in output: '$kw'" >&2
    fail_count=$((fail_count + 1))
  fi
done

if [ "$fail_count" -gt 0 ]; then
  echo "Output was:" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

# assert_order: 2-anchor check only (session-start → plan).
# Middle keywords are reordered freely by LLM; anchors verify gate→transition outline.
assert_order "session-start" "plan" || {
  echo "FAIL: session-start must appear before plan in output" >&2
  exit 1
}

echo "PASS: fast-discover (all ${#KEYWORDS[@]} keywords found, gate→transition order confirmed)"
exit 0
