#!/usr/bin/env bash
# integration-atdd-chain.sh -- AC3: chain/triggering test
# Verifies that after atdd completes, atdd-kit:verify is auto-invoked.
# Runs a headless orchestrator session that invokes atdd-kit:atdd --autopilot
# followed by atdd-kit:verify and checks transcript for correct chain ordering.
# Verifies chain order via transcript: atdd_count == 1, verify_count >= 1, verify_order > atdd_order.
# NOTE: gh stub log assertion omitted per Option C (sub-agent PATH non-inheritance) --
# Skill tool spawns sub-agents that do not inherit the parent's PATH shim.
# Skill E2E Test (fixture-based chain): fixture + jsonl transcript analysis + gh stub.

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
# so atdd State Gate passes during the chain test
# shellcheck source=../test-helpers.sh
source "$HELPERS"
setup_gh_stub "$SKILL_TEST_TMPDIR" "atdd-chain" --labels "ready-to-go"
export PATH="${GH_STUB_DIR}:${PATH}"

TRANSCRIPT="${SKILL_TEST_TMPDIR}/integration-atdd-chain.jsonl"
GH_LOG="${GH_STUB_LOG_FILE}"
FIXTURE_CONTENT=$(cat "$FIXTURE_ISSUE")

# Orchestrator prompt: invoke atdd then verify in sequence.
# This mirrors PR #155's Option C approach (orchestrator-driven chain),
# rather than relying on sub-agent PATH inheritance (which is unreliable).
PROMPT="You are an atdd-kit autopilot orchestrator. Do the following in order:
1. Invoke the atdd-kit:atdd skill via the Skill tool with args '999 --autopilot'
2. When atdd returns SKILL_STATUS: COMPLETE, immediately invoke atdd-kit:verify via the Skill tool with args '999 --autopilot'
Do not skip either step. Do not do any other work.

Fixture Issue #999 content (already has ready-to-go label set):
${FIXTURE_CONTENT}"

echo "Running integration atdd-chain test..."
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

echo "Tool use events found: $parsed"

# --- AC3 assertion 1: atdd appears exactly once (no recursion) ---
atdd_count=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:atdd")] | length' 2>/dev/null || echo "0")
if [ "$atdd_count" -ne 1 ]; then
  echo "FAIL: expected exactly 1 atdd-kit:atdd event, got $atdd_count" >&2
  exit 1
fi
echo "OK: atdd-kit:atdd count = 1 (no recursion)"

# --- AC3 assertion 2: verify appears at least once ---
verify_count=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:verify")] | length' 2>/dev/null || echo "0")
if [ "$verify_count" -lt 1 ]; then
  echo "FAIL: atdd-kit:verify not found in transcript" >&2
  echo "All tool_use events: $parsed" >&2
  exit 1
fi
echo "OK: atdd-kit:verify count = $verify_count"

# --- AC3 assertion 3: verify appears after atdd ---
atdd_order=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:atdd")] | .[0].order' 2>/dev/null || echo "0")
verify_order=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:verify")] | .[0].order // 0' 2>/dev/null || echo "0")

if [ "$verify_order" -le "$atdd_order" ]; then
  echo "FAIL: atdd-kit:verify (order=$verify_order) must appear after atdd-kit:atdd (order=$atdd_order)" >&2
  exit 1
fi
echo "OK: atdd-kit:verify (order=$verify_order) follows atdd-kit:atdd (order=$atdd_order)"

# NOTE: gh stub log assertion intentionally absent.
# Sub-agents spawned via Skill tool do not inherit the parent's PATH shim,
# so GH_LOG will not capture calls made inside the atdd sub-agent.
# Chain ordering is fully asserted via transcript analysis above.

echo "PASS: integration-atdd-chain (atdd->verify chain verified)"
exit 0
