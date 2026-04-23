#!/usr/bin/env bash
# integration-atdd.sh -- AC2: integration L4 test for atdd skill headless invocation
# Runs atdd in headless mode on a fixture issue and verifies:
#   1. skill_transcript_parser.sh reports atdd-kit:atdd tool_use (operates on parser output,
#      not raw transcript — parser emits {name, args, order} per Skill tool_use)
#   2. assistant text contains SKILL_STATUS declaration in a skill-status code fence
#   3. gh-calls-atdd.log contains issue view --json labels (State Gate check)
# Integration layer: fixture + jsonl transcript analysis + gh stub with ready-to-go label.

set -u
set -o pipefail

: "${SKILL_TEST_TMPDIR:?SKILL_TEST_TMPDIR must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
FIXTURE_ISSUE="${SCRIPT_DIR}/../fixtures/atdd-fixture-issue.md"
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

_timeout_prefix() {
  if command -v timeout > /dev/null 2>&1; then
    echo "timeout $TIMEOUT_SECS"
  elif command -v gtimeout > /dev/null 2>&1; then
    echo "gtimeout $TIMEOUT_SECS"
  else
    echo ""
  fi
}

# Load test helpers and install gh stub with ready-to-go label
# so atdd State Gate (which checks for ready-to-go) passes
# shellcheck source=../test-helpers.sh
source "$HELPERS"
setup_gh_stub "$SKILL_TEST_TMPDIR" "atdd" --labels "ready-to-go"
export PATH="${GH_STUB_DIR}:${PATH}"

TRANSCRIPT="${SKILL_TEST_TMPDIR}/integration-atdd.jsonl"
GH_LOG="${GH_STUB_LOG_FILE}"

FIXTURE_CONTENT=$(cat "$FIXTURE_ISSUE")

PROMPT="You are an atdd-kit autopilot agent. Run the atdd skill with --autopilot on the following Issue. \
The Issue is #999. Read the Issue content and invoke the atdd-kit:atdd skill via the Skill tool with args '999 --autopilot'. \
The issue already has ready-to-go label set.

Issue content:
${FIXTURE_CONTENT}"

echo "Running integration atdd test..."
echo "Transcript: $TRANSCRIPT"

TIMEOUT_PREFIX=$(_timeout_prefix)
if [ -n "$TIMEOUT_PREFIX" ]; then
  # shellcheck disable=SC2086
  ${TIMEOUT_PREFIX} "$CLAUDE_BIN" -p "$PROMPT" \
    --permission-mode bypassPermissions \
    --output-format stream-json \
    --verbose \
    --plugin-dir "$REPO_ROOT" \
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
    --plugin-dir "$REPO_ROOT" \
    2>/dev/null > "$TRANSCRIPT" || true
fi

# --- Assertion 1: transcript contains atdd-kit:atdd tool_use ---
# Note: assertion operates on skill_transcript_parser.sh output, not raw transcript.
# Parser emits JSON array of {name: <skill-name>, args, order} per Skill tool_use event.
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

atdd_count=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:atdd")] | length' 2>/dev/null || echo "0")
if [ "$atdd_count" -lt 1 ]; then
  echo "FAIL: no atdd-kit:atdd tool_use found in transcript" >&2
  echo "Parsed tool_use events: $parsed" >&2
  exit 1
fi
echo "OK: atdd-kit:atdd tool_use found ($atdd_count event(s))"

# --- Assertion 2: SKILL_STATUS declaration in skill-status fence ---
STDOUT_TEXT=$(jq -r 'select(.type == "result") | .result // empty' "$TRANSCRIPT" 2>/dev/null)
if [ -z "$STDOUT_TEXT" ]; then
  STDOUT_TEXT=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' "$TRANSCRIPT" 2>/dev/null | tr -d '\r')
fi

if [ -z "$STDOUT_TEXT" ]; then
  echo "FAIL: could not extract assistant text from transcript" >&2
  exit 1
fi

if ! printf '%s\n' "$STDOUT_TEXT" | sed -n '/^```skill-status$/,/^```$/p' | grep -qE "SKILL_STATUS: (COMPLETE|PENDING|BLOCKED|FAILED)"; then
  echo "FAIL: SKILL_STATUS declaration not found in skill-status code fence" >&2
  printf '%s\n' "$STDOUT_TEXT" | head -60 >&2
  exit 1
fi
echo "OK: SKILL_STATUS declaration confirmed in skill-status fence"

# --- Assertion 3: State Gate gh call logged (issue view --json labels) ---
if [ ! -f "$GH_LOG" ]; then
  echo "FAIL: gh call log not found: $GH_LOG" >&2
  exit 1
fi

if grep -qE "issue view.*--json labels|issue view [0-9]+ --json labels" "$GH_LOG"; then
  echo "OK: State Gate check (issue view --json labels) logged"
else
  echo "FAIL: State Gate check (issue view --json labels) not found in $GH_LOG" >&2
  echo "gh calls logged:" >&2
  cat "$GH_LOG" >&2
  exit 1
fi

echo "PASS: integration-atdd"
exit 0
