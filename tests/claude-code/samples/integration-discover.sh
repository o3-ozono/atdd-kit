#!/usr/bin/env bash
# integration-discover.sh -- AC2: integration L4 test for discover skill
# Runs discover in headless mode on a fixture issue and verifies:
#   1. skill_transcript_parser.sh reports atdd-kit:discover tool_use
#   2. stdout contains SKILL_STATUS: COMPLETE in a skill-status code fence
#   3. gh-calls-discover.log contains issue edit --add-label in-progress (lock acquisition)
# Skill E2E Test (fixture-based chain): fixture + jsonl transcript analysis + gh stub.

set -u
set -o pipefail

: "${SKILL_TEST_TMPDIR:?SKILL_TEST_TMPDIR must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
FIXTURE_ISSUE="${SCRIPT_DIR}/../fixtures/discover-fixture-issue.md"
PARSER="${REPO_ROOT}/lib/skill_transcript_parser.sh"
HELPERS="${SCRIPT_DIR}/../test-helpers.sh"
CLAUDE_BIN="${SKILL_TEST_CLAUDE_BIN:-claude}"
TIMEOUT_SECS="${SKILL_TEST_TIMEOUT_SECS:-600}"

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

# Resolve timeout command: GNU timeout (Linux) or gtimeout (macOS via coreutils)
_timeout_prefix() {
  if command -v timeout > /dev/null 2>&1; then
    echo "timeout $TIMEOUT_SECS"
  elif command -v gtimeout > /dev/null 2>&1; then
    echo "gtimeout $TIMEOUT_SECS"
  else
    echo ""
  fi
}

# Load test helpers and install gh stub
# shellcheck source=../test-helpers.sh
source "$HELPERS"
setup_gh_stub "$SKILL_TEST_TMPDIR" "discover"
export PATH="${GH_STUB_DIR}:${PATH}"

TRANSCRIPT="${SKILL_TEST_TMPDIR}/integration-discover.jsonl"
GH_LOG="${GH_STUB_LOG_FILE}"

FIXTURE_CONTENT=$(cat "$FIXTURE_ISSUE")

PROMPT="You are an atdd-kit autopilot agent. Run the discover skill with --autopilot on the following Issue content. \
The Issue is #999. Read the Issue content and invoke the atdd-kit:discover skill via the Skill tool with args '999 --autopilot'.

Issue content:
${FIXTURE_CONTENT}"

echo "Running integration discover test..."
echo "Transcript: $TRANSCRIPT"

# Single claude -p invocation with stream-json (--verbose required in -p mode)
# SKILL_STATUS is extracted from assistant text blocks in the transcript
TIMEOUT_PREFIX=$(_timeout_prefix)
if [ -n "$TIMEOUT_PREFIX" ]; then
  # shellcheck disable=SC2086
  ${TIMEOUT_PREFIX} "$CLAUDE_BIN" -p "$PROMPT" \
    --permission-mode bypassPermissions \
    --output-format stream-json \
    --verbose \
    2>/dev/null > "$TRANSCRIPT" || {
    exit_code=$?
    [ "$exit_code" -eq 124 ] && { echo "FAIL: timeout after ${TIMEOUT_SECS}s" >&2; exit 1; }
    echo "FAIL: claude exited with code $exit_code" >&2
    exit 1
  }
else
  "$CLAUDE_BIN" -p "$PROMPT" \
    --permission-mode bypassPermissions \
    --output-format stream-json \
    --verbose \
    2>/dev/null > "$TRANSCRIPT" || true
fi

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

# --- Assertion 2: SKILL_STATUS: COMPLETE in skill-status fence ---
# Extract assistant text from stream-json transcript (result message or assistant content blocks)
STDOUT_TEXT=$(jq -r 'select(.type == "result") | .result // empty' "$TRANSCRIPT" 2>/dev/null)
if [ -z "$STDOUT_TEXT" ]; then
  STDOUT_TEXT=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' "$TRANSCRIPT" 2>/dev/null | tr -d '\r')
fi

if [ -z "$STDOUT_TEXT" ]; then
  echo "FAIL: could not extract assistant text from transcript" >&2
  exit 1
fi

if ! printf '%s\n' "$STDOUT_TEXT" | sed -n '/^```skill-status$/,/^```$/p' | grep -q "SKILL_STATUS: COMPLETE"; then
  echo "FAIL: SKILL_STATUS: COMPLETE not found in skill-status code fence" >&2
  printf '%s\n' "$STDOUT_TEXT" | head -60 >&2
  exit 1
fi
echo "OK: SKILL_STATUS: COMPLETE confirmed in skill-status fence"

# --- Assertion 3: gh lock acquisition logged (issue edit --add-label in-progress) --- HARD FAIL
if [ ! -f "$GH_LOG" ]; then
  echo "FAIL: gh call log not found: $GH_LOG" >&2
  exit 1
fi

if grep -qE "issue edit.*--add-label.*in-progress|issue edit.*in-progress" "$GH_LOG"; then
  echo "OK: gh lock acquisition (issue edit --add-label in-progress) logged"
else
  echo "FAIL: gh lock acquisition (issue edit --add-label in-progress) not found in $GH_LOG" >&2
  echo "gh calls logged:" >&2
  cat "$GH_LOG" >&2
  exit 1
fi

echo "PASS: integration-discover"
exit 0
