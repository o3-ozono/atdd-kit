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
#   SKILL_TEST_PLUGIN_DIR             — plugin directory to load via
#                                       `claude -p --plugin-dir`; defaults
#                                       to $REPO_ROOT (the worktree the
#                                       test is running from). Set to a
#                                       pre-fix worktree (e.g. checkout
#                                       of main) to drive the RED state
#                                       in ATDD verification.
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
PLUGIN_DIR="${SKILL_TEST_PLUGIN_DIR:-$REPO_ROOT}"

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "Error: plugin dir not found: $PLUGIN_DIR" >&2
  exit 3
fi
if [ ! -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]; then
  echo "Error: plugin manifest not found: $PLUGIN_DIR/.claude-plugin/plugin.json" >&2
  exit 3
fi

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

# Prompt design (ATDD-correct, Issue #162):
#   Self-contained — does not reference any file path on disk so the
#   orchestrator is forced to rely on the plugin-dir-provided
#   /atdd-kit:autopilot slash command and skill definitions for its
#   procedure knowledge. Combined with the cwd isolation in run_once,
#   this ensures Claude's behavior is driven only by the loaded plugin
#   (the artifact under test). The variable across RED/GREEN runs is
#   exactly $SKILL_TEST_PLUGIN_DIR (a pre-fix vs fix-applied checkout).
PROMPT=$(cat <<PROMPT_EOF
You are the atdd-kit autopilot orchestrator. Issue #999 is a bug-type
Issue and needs Phase 1 work. Follow the standard /atdd-kit:autopilot
Phase 1 procedure for this Issue: invoke the discover skill in
--autopilot mode with args '999 --autopilot' and apply the appropriate
Phase 1 transition behavior. Stop after the immediate Phase 1 transition
action completes; do not proceed to Phase 2 or later. Do not invent
extra steps. Do not read repository files outside what your plugin
context provides — rely solely on your loaded /atdd-kit slash command
and skill definitions.

Fixture Issue #999 content:
${FIXTURE_CONTENT}
PROMPT_EOF
)

TIMEOUT_PREFIX=$(_timeout_prefix)

run_once() {
  local idx="$1"
  local transcript="$2"
  # Run claude from an isolated cwd that has no atdd-kit context. This
  # prevents leakage of repo-state implementation details (e.g. the fix
  # worktree's commands/autopilot.md, lib/transition_detector.sh, test
  # fixtures, .git history) into the orchestrator's context. Plugin
  # behavior is the sole variable, supplied via --plugin-dir, with the
  # autopilot procedure injected as system prompt from $PLUGIN_DIR so
  # the orchestrator's dispatch awareness tracks the plugin under test.
  local isolated_cwd="${SKILL_TEST_TMPDIR}/cwd-${idx}"
  mkdir -p "$isolated_cwd"
  local autopilot_md="${PLUGIN_DIR}/commands/autopilot.md"
  if [ ! -f "$autopilot_md" ]; then
    echo "Error: autopilot.md not found in plugin dir: $autopilot_md" >&2
    return 3
  fi
  if [ -n "$TIMEOUT_PREFIX" ]; then
    # shellcheck disable=SC2086
    ( cd "$isolated_cwd" && \
      ${TIMEOUT_PREFIX} "$CLAUDE_BIN" -p "$PROMPT" \
        --permission-mode bypassPermissions \
        --plugin-dir "$PLUGIN_DIR" \
        --append-system-prompt-file "$autopilot_md" \
        --output-format stream-json \
        --verbose \
        2>/dev/null > "$transcript" )
    return $?
  else
    ( cd "$isolated_cwd" && \
      "$CLAUDE_BIN" -p "$PROMPT" \
        --permission-mode bypassPermissions \
        --plugin-dir "$PLUGIN_DIR" \
        --append-system-prompt-file "$autopilot_md" \
        --output-format stream-json \
        --verbose \
        2>/dev/null > "$transcript" )
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

  # AC1/AC2 assertion — all true:
  #   same_turn_spawn == true: aggregated has Agent calls within current
  #     response turn (bounded by next real user input).
  #   agent_count == 2: bug-triage spawn pattern (Tester + Developer).
  # Legacy delta/intervening checks were dropped because headless mode
  # injects a runtime "Base directory for this skill:" user-text msg
  # between carrier and model's first assistant message — same_turn_spawn
  # already absorbs that semantic.
  same_turn=$(jq -r '.same_turn_spawn' <<< "$detector_out")
  agent_count=$(jq '[.aggregated_tool_uses[] | select(. == "Agent")] | length' <<< "$detector_out")

  ok=1
  if [ "$same_turn" != "true" ]; then ok=0; fi
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
