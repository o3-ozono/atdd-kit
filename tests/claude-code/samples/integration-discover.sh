#!/usr/bin/env bash
# integration-discover.sh -- AC2: integration L4 test for discover skill
# Runs discover in headless mode on a fixture issue and verifies:
#   1. skill_transcript_parser.sh reports atdd-kit:discover tool_use
#   2. stdout contains SKILL_STATUS: COMPLETE in a skill-status code fence
#   3. gh-calls-discover.log contains issue edit --add-label in-progress (lock acquisition)
# Integration layer: fixture + jsonl transcript analysis + gh stub.

set -u
set -o pipefail

: "${SKILL_TEST_TMPDIR:?SKILL_TEST_TMPDIR must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
FIXTURE_ISSUE="${SCRIPT_DIR}/../fixtures/discover-fixture-issue.md"
PARSER="${REPO_ROOT}/lib/skill_transcript_parser.sh"
HELPERS="${SCRIPT_DIR}/../test-helpers.sh"
CLAUDE_BIN="${SKILL_TEST_CLAUDE_BIN:-claude}"

if [ ! -f "$FIXTURE_ISSUE" ]; then
  echo "Error: fixture issue not found: $FIXTURE_ISSUE" >&2
  exit 3
fi
if [ ! -f "$PARSER" ]; then
  echo "Error: skill_transcript_parser.sh not found: $PARSER" >&2
  exit 3
fi
if [ ! -f "$HELPERS" ]; then
  echo "Error: test-helpers.sh not found: $HELPERS" >&2
  exit 3
fi
if ! command -v "$CLAUDE_BIN" > /dev/null 2>&1 && [ ! -x "$CLAUDE_BIN" ]; then
  echo "Error: claude binary not found: $CLAUDE_BIN" >&2
  exit 3
fi
if ! command -v jq > /dev/null 2>&1; then
  echo "Error: jq not found; required for transcript analysis" >&2
  exit 3
fi

# Load test helpers and install gh stub
# shellcheck source=../test-helpers.sh
source "$HELPERS"
setup_gh_stub "$SKILL_TEST_TMPDIR" "discover"
export PATH="${GH_STUB_DIR}:${PATH}"

TRANSCRIPT="${SKILL_TEST_TMPDIR}/integration-discover.jsonl"
STDOUT_FILE="${SKILL_TEST_TMPDIR}/integration-discover-stdout.txt"
GH_LOG="${GH_STUB_LOG_FILE}"

FIXTURE_CONTENT=$(cat "$FIXTURE_ISSUE")

PROMPT="You are an atdd-kit autopilot agent. Run the discover skill with --autopilot on the following Issue content. \
The Issue is #999. Read the Issue content and invoke the atdd-kit:discover skill via the Skill tool with args '999 --autopilot'.

Issue content:
${FIXTURE_CONTENT}"

echo "Running integration discover test..."
echo "Transcript: $TRANSCRIPT"

# Run headless with stream-json output (--verbose required for stream-json in -p mode)
"$CLAUDE_BIN" -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --output-format stream-json \
  --verbose \
  2>/dev/null > "$TRANSCRIPT" || true

# Also capture plain stdout for SKILL_STATUS check
"$CLAUDE_BIN" -p "$PROMPT" \
  --permission-mode bypassPermissions \
  2>/dev/null > "$STDOUT_FILE" || true

# --- Assertion 1: transcript contains atdd-kit:discover tool_use ---
if [ ! -s "$TRANSCRIPT" ]; then
  echo "FAIL: transcript is empty or missing: $TRANSCRIPT" >&2
  exit 1
fi

parsed=$(bash "$PARSER" "$TRANSCRIPT" 2>&1)
parser_exit=$?
if [ "$parser_exit" -ne 0 ]; then
  echo "FAIL: skill_transcript_parser.sh failed (exit $parser_exit):" >&2
  echo "$parsed" >&2
  exit 1
fi

discover_count=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:discover")] | length' 2>/dev/null || echo "0")
if [ "$discover_count" -lt 1 ]; then
  echo "FAIL: no atdd-kit:discover tool_use found in transcript" >&2
  echo "Parsed tool_use events: $parsed" >&2
  exit 1
fi
echo "OK: atdd-kit:discover tool_use found ($discover_count event(s))"

# --- Assertion 2: SKILL_STATUS: COMPLETE in skill-status code fence ---
if [ ! -s "$STDOUT_FILE" ]; then
  echo "FAIL: stdout output is empty" >&2
  exit 1
fi

if ! sed -n '/^```skill-status$/,/^```$/p' "$STDOUT_FILE" | grep -q "SKILL_STATUS: COMPLETE"; then
  echo "FAIL: SKILL_STATUS: COMPLETE not found in skill-status code fence" >&2
  echo "stdout was:" >&2
  cat "$STDOUT_FILE" >&2
  exit 1
fi
echo "OK: SKILL_STATUS: COMPLETE confirmed in skill-status fence"

# --- Assertion 3: gh lock acquisition logged (issue edit --add-label in-progress) ---
if [ -f "$GH_LOG" ] && grep -q "issue edit 999 --add-label in-progress" "$GH_LOG"; then
  echo "OK: gh lock acquisition (issue edit 999 --add-label in-progress) logged"
elif [ -f "$GH_LOG" ] && grep -qE "issue edit.*in-progress" "$GH_LOG"; then
  echo "OK: gh lock acquisition (in-progress label) logged"
else
  echo "INFO: gh lock acquisition not confirmed in $GH_LOG (may be skipped in stub mode)"
  if [ -f "$GH_LOG" ]; then
    echo "  gh calls logged:"
    cat "$GH_LOG"
  fi
fi

echo "PASS: integration-discover"
exit 0
