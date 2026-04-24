#!/usr/bin/env bash
# integration-autopilot-phase1-transition.sh
#
# Issue #162 (regression of #83/#101): verify that a main-Claude orchestrator,
# given a bug-type Issue, invokes atdd-kit:discover --autopilot and then
# issues Agent tool calls in the SAME assistant response turn as the
# skill-status COMPLETE + NEXT_REQUIRED_ACTION: spawn_ac_review_agents.
#
# This is the runtime L4 counterpart to the static bats suites
# (test_autopilot_phase1_transition.bats / test_transition_detector.bats).
#
# Assertions rely on lib/transition_detector.sh.
#
# Config (env):
#   SKILL_TEST_TMPDIR                 — required (bats harness provides)
#   SKILL_TEST_CLAUDE_BIN             — defaults to `claude`
#   SKILL_TEST_TIMEOUT_SECS           — per-run timeout, default 600
#   PHASE1_TRANSITION_TEST_N          — number of runs (default 1)
#   PHASE1_TRANSITION_REQUIRED_PASSES — required same-turn passes (default N)
#
# Exit codes:
#   0   PASS (required passes met)
#   1   FAIL (insufficient same-turn passes, or detector parse error)
#   3   environment error (missing dependency / fixture)
#   124 timeout

set -u
set -o pipefail

: "${SKILL_TEST_TMPDIR:?SKILL_TEST_TMPDIR must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
FIXTURE_ISSUE="${SCRIPT_DIR}/../fixtures/autopilot-phase1-bug-fixture-issue.md"
DETECTOR="${REPO_ROOT}/lib/transition_detector.sh"
HELPERS="${SCRIPT_DIR}/../test-helpers.sh"
CLAUDE_BIN="${SKILL_TEST_CLAUDE_BIN:-claude}"
TIMEOUT_SECS="${SKILL_TEST_TIMEOUT_SECS:-600}"

N="${PHASE1_TRANSITION_TEST_N:-1}"
REQUIRED_PASSES="${PHASE1_TRANSITION_REQUIRED_PASSES:-$N}"

if [ ! -f "$FIXTURE_ISSUE" ]; then
  echo "Error: fixture issue not found: $FIXTURE_ISSUE" >&2
  exit 3
fi
if [ ! -f "$DETECTOR" ]; then
  echo "Error: transition_detector.sh not found: $DETECTOR" >&2
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
  echo "Error: jq is required" >&2
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

# shellcheck source=../test-helpers.sh
source "$HELPERS"
setup_gh_stub "$SKILL_TEST_TMPDIR" "phase1-transition"
export PATH="${GH_STUB_DIR}:${PATH}"

FIXTURE_CONTENT=$(cat "$FIXTURE_ISSUE")

# Prompt instructs the orchestrator to:
#   1. Invoke atdd-kit:discover with 999 --autopilot
#   2. On SKILL_STATUS: COMPLETE + NEXT_REQUIRED_ACTION: spawn_ac_review_agents,
#      spawn two Agent tool calls (Tester + Developer — bug-triage per
#      autopilot.md AC Review Round) in the SAME response turn.
PROMPT=$(cat <<PROMPT_EOF
You are the atdd-kit autopilot orchestrator (Phase 1). Follow this
procedure exactly:

1. Invoke the atdd-kit:discover skill via the Skill tool with args
   '999 --autopilot'.

2. When discover returns a skill-status block containing
   SKILL_STATUS: COMPLETE and NEXT_REQUIRED_ACTION: spawn_ac_review_agents,
   you must IMMEDIATELY — in the SAME assistant response turn — issue TWO
   Agent tool calls in parallel to spawn the bug-triage AC Review Round:
     - one Agent with subagent_type="tester"
     - one Agent with subagent_type="developer"
   Each with any short description/prompt of your choice.

Do NOT output any user-facing text between receiving the skill-status
block and issuing the Agent tool calls. Do NOT end your response with
text-only before the Agent tool calls.

Fixture Issue #999 content:
${FIXTURE_CONTENT}
PROMPT_EOF
)

TIMEOUT_PREFIX=$(_timeout_prefix)

run_once() {
  local idx="$1"
  local transcript="$2"
  if [ -n "$TIMEOUT_PREFIX" ]; then
    # shellcheck disable=SC2086
    ${TIMEOUT_PREFIX} "$CLAUDE_BIN" -p "$PROMPT" \
      --permission-mode bypassPermissions \
      --output-format stream-json \
      --verbose \
      2>/dev/null > "$transcript"
    return $?
  else
    "$CLAUDE_BIN" -p "$PROMPT" \
      --permission-mode bypassPermissions \
      --output-format stream-json \
      --verbose \
      2>/dev/null > "$transcript"
    return $?
  fi
}

passes=0
fails=0

for i in $(seq 1 "$N"); do
  transcript="${SKILL_TEST_TMPDIR}/integration-autopilot-phase1-transition.run-${i}.jsonl"
  echo "[run ${i}/${N}] transcript=${transcript}"

  run_once "$i" "$transcript"
  rc=$?
  if [ "$rc" -eq 124 ]; then
    echo "FAIL[${i}]: timeout after ${TIMEOUT_SECS}s" >&2
    fails=$((fails + 1))
    continue
  fi
  if [ ! -s "$transcript" ]; then
    echo "FAIL[${i}]: transcript is empty or missing" >&2
    fails=$((fails + 1))
    continue
  fi

  detector_out=$(bash "$DETECTOR" "$transcript" 2>&1)
  detector_rc=$?
  if [ "$detector_rc" -ne 0 ]; then
    echo "FAIL[${i}]: transition_detector returned $detector_rc" >&2
    echo "${detector_out}" >&2
    fails=$((fails + 1))
    continue
  fi

  # AC1/AC2 assertion — all six must be true.
  same_turn=$(jq -r '.same_turn_spawn' <<< "$detector_out")
  delta=$(jq -r '.next_assistant_msg_index - .skill_result_user_msg_index' <<< "$detector_out")
  intervening=$(jq -r '.intervening_user_msgs' <<< "$detector_out")
  agent_count=$(jq '[.next_assistant_tool_uses[] | select(. == "Agent")] | length' <<< "$detector_out")

  ok=1
  if [ "$same_turn" != "true" ]; then ok=0; fi
  if [ "$delta" != "1" ]; then ok=0; fi
  if [ "$intervening" != "0" ]; then ok=0; fi
  if [ "$agent_count" != "2" ]; then ok=0; fi

  if [ "$ok" -eq 1 ]; then
    echo "PASS[${i}]: same-turn spawn with 2 Agents, 0 intervening user msgs"
    passes=$((passes + 1))
  else
    echo "FAIL[${i}]: assertions failed" >&2
    echo "  detector_out: $detector_out" >&2
    fails=$((fails + 1))
  fi
done

echo "Summary: $passes pass / $fails fail out of $N (required: $REQUIRED_PASSES)"

if [ "$passes" -ge "$REQUIRED_PASSES" ]; then
  exit 0
fi
exit 1
