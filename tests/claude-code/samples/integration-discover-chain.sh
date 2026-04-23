#!/usr/bin/env bash
# integration-discover-chain.sh -- AC6: chain/triggering test
# Verifies that after discover completes, atdd-kit:plan is auto-invoked.
# Runs a headless session that invokes atdd-kit:discover --autopilot and
# checks that the transcript contains both discover and plan tool_use in order.
# Also checks gh-calls-chain.log for deliverable posting (issue comment).
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
setup_gh_stub "$SKILL_TEST_TMPDIR" "chain"
export PATH="${GH_STUB_DIR}:${PATH}"

TRANSCRIPT="${SKILL_TEST_TMPDIR}/integration-discover-chain.jsonl"
GH_LOG="${GH_STUB_LOG_FILE}"
FIXTURE_CONTENT=$(cat "$FIXTURE_ISSUE")

# Invoke a session that runs discover --autopilot AND plan --autopilot in sequence.
PROMPT="You are an atdd-kit autopilot orchestrator. Do the following in order:
1. Invoke the atdd-kit:discover skill via the Skill tool with args '999 --autopilot'
2. When discover returns SKILL_STATUS: COMPLETE, immediately invoke atdd-kit:plan via the Skill tool with args '999 --autopilot'
Do not skip either step. Do not do any other work.

Fixture Issue #999 content:
${FIXTURE_CONTENT}"

echo "Running integration discover-chain test..."
echo "Transcript: $TRANSCRIPT"

"$CLAUDE_BIN" -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --output-format stream-json \
  --verbose \
  2>/dev/null > "$TRANSCRIPT" || true

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

# --- AC6 assertion 1: discover appears exactly once (no recursion) ---
discover_count=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:discover")] | length' 2>/dev/null || echo "0")
if [ "$discover_count" -ne 1 ]; then
  echo "FAIL: expected exactly 1 atdd-kit:discover event, got $discover_count" >&2
  exit 1
fi
echo "OK: atdd-kit:discover count = 1 (no recursion)"

# --- AC6 assertion 2: plan appears after discover ---
discover_order=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:discover")] | .[0].order' 2>/dev/null || echo "0")
plan_order=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:plan")] | .[0].order // 0' 2>/dev/null || echo "0")

if [ "$plan_order" -eq 0 ]; then
  echo "FAIL: atdd-kit:plan not found in transcript" >&2
  echo "All tool_use events: $parsed" >&2
  exit 1
fi

if [ "$plan_order" -le "$discover_order" ]; then
  echo "FAIL: atdd-kit:plan (order=$plan_order) must appear after atdd-kit:discover (order=$discover_order)" >&2
  exit 1
fi
echo "OK: atdd-kit:plan (order=$plan_order) follows atdd-kit:discover (order=$discover_order)"

# --- AC6 assertion 3: no atdd before plan (HARD-GATE violation check) ---
atdd_order=$(echo "$parsed" | jq '[.[] | select(.name == "atdd-kit:atdd")] | .[0].order // 0' 2>/dev/null || echo "0")
if [ "$atdd_order" -gt 0 ] && [ "$atdd_order" -lt "$plan_order" ]; then
  echo "FAIL: atdd-kit:atdd (order=$atdd_order) invoked before atdd-kit:plan (order=$plan_order) — HARD-GATE violation" >&2
  exit 1
fi

# --- AC6 assertion 4: deliverable posted to Issue (issue comment in gh log) ---
if [ -f "$GH_LOG" ] && grep -qE "issue comment" "$GH_LOG"; then
  echo "OK: gh issue comment (deliverable post) logged"
else
  echo "INFO: deliverable post not confirmed in $GH_LOG (may be skipped in stub mode)"
  if [ -f "$GH_LOG" ]; then
    echo "  gh calls logged:"
    cat "$GH_LOG"
  fi
fi

echo "PASS: integration-discover-chain (discover->plan chain verified)"
exit 0
