#!/usr/bin/env bash
# fast-defining-requirements.sh -- Skill Acceptance Test (fast layer) for
# the defining-requirements skill (Issue #188, Step B1 of #179).
# Verifies that Claude can read the skill definition and identify the
# v1.0 PRD-derivation flow keywords in expected order.
# Fast layer: single-turn claude -p, no fixture project, no skill chain.

set -u
set -o pipefail

: "${SKILL_TEST_TMPDIR:?SKILL_TEST_TMPDIR must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
HELPERS="${SCRIPT_DIR}/../test-helpers.sh"
FIXTURE="${SCRIPT_DIR}/../fixtures/defining-requirements-keywords.txt"

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

SKILL_FILE="${REPO_ROOT}/skills/defining-requirements/SKILL.md"
if [ ! -f "$SKILL_FILE" ]; then
  echo "Error: defining-requirements SKILL.md not found: $SKILL_FILE" >&2
  exit 3
fi

CLAUDE_BIN=$(_claude_bin)
if [ -z "$CLAUDE_BIN" ]; then
  echo "Error: claude binary not found; set SKILL_TEST_CLAUDE_BIN or install claude" >&2
  exit 3
fi

TIMEOUT_SECS="${SKILL_TEST_TIMEOUT_SECS:-120}"

_timeout_cmd() {
  if command -v timeout > /dev/null 2>&1; then
    echo "timeout $TIMEOUT_SECS"
  elif command -v gtimeout > /dev/null 2>&1; then
    echo "gtimeout $TIMEOUT_SECS"
  else
    echo ""
  fi
}

KEYWORDS=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  KEYWORDS+=("$line")
done < <(grep -v '^[[:space:]]*$' "$FIXTURE")

if [ "${#KEYWORDS[@]}" -eq 0 ]; then
  echo "Error: keyword fixture is empty: $FIXTURE" >&2
  exit 3
fi

SKILL_CONTENT=$(cat "$SKILL_FILE")

PROMPT="The following is the atdd-kit defining-requirements skill definition. \
Respond in English. \
List the key concepts and terms that appear in it, in the order they are introduced. \
Include: prerequisites, the six PRD sections, the artifact output path, the User Story format note, the downstream transition target, and the status output block.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"

echo "Running fast defining-requirements test (timeout=${TIMEOUT_SECS}s)..."

TIMEOUT_PREFIX=$(_timeout_cmd)

if [ -n "$TIMEOUT_PREFIX" ]; then
  # shellcheck disable=SC2086
  OUTPUT=$(${TIMEOUT_PREFIX} "$CLAUDE_BIN" -p "$PROMPT" \
    --max-turns 1 \
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
    --max-turns 1 \
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

# 2-anchor check: session-start (Upstream) must precede extracting-user-stories (Downstream)
assert_order "session-start" "extracting-user-stories" || {
  echo "FAIL: session-start must appear before extracting-user-stories in output" >&2
  exit 1
}

echo "PASS: fast-defining-requirements (all ${#KEYWORDS[@]} keywords found, upstream→downstream order confirmed)"
exit 0
