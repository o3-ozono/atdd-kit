#!/usr/bin/env bash
# test-skills-headless.sh -- Headless skill-chain integration test runner
# Issue #72 / AC1 (live), AC2 (replay), AC5 (exit codes)
#
# Usage:
#   scripts/test-skills-headless.sh <scenario.json>                 # live mode
#   scripts/test-skills-headless.sh --replay <transcript> <scenario.json>
#
# Exit codes (AC5):
#   0 — assertion PASS
#   1 — assertion FAIL
#   2 — parse_error (malformed transcript)
#   3 — infra (missing claude binary, missing jq, scenario schema violation,
#              unreadable file, invalid CLI usage)
#   4 — timeout (live mode claude invocation exceeded scenario.timeout)
#
# Testability env vars (public API, per Plan v2 §Runner 仕様):
#   HEADLESS_CLAUDE_BIN — override the claude binary path (default: PATH lookup)
#   HEADLESS_TEMP_DIR   — override the transcript output dir (default: mktemp -d)
#
# SIGINT / SIGTERM in live mode:
#   - kills the claude subprocess (and child process group if supported)
#   - removes the temp transcript file
#   - exits with 130 (SIGINT) or 143 (SIGTERM)

set -u
set -o pipefail

# Resolve repo root relative to this script so lib/ can be sourced regardless of cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PARSER="${REPO_ROOT}/lib/skill_transcript_parser.sh"
ASSERT="${REPO_ROOT}/lib/skill_assertion.sh"
LOADER="${REPO_ROOT}/lib/scenario_loader.sh"

# ---------------------------------------------------------------------------
# Usage / arg parsing
# ---------------------------------------------------------------------------
usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/test-skills-headless.sh <scenario.json>                  # live mode
  scripts/test-skills-headless.sh --replay <transcript> <scenario.json>

Exit codes: 0 PASS, 1 assertion FAIL, 2 parse_error, 3 infra, 4 timeout.

Env vars (testability):
  HEADLESS_CLAUDE_BIN  override claude binary path
  HEADLESS_TEMP_DIR    override transcript output dir
EOF
}

MODE="live"
TRANSCRIPT=""
SCENARIO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --replay)
      MODE="replay"
      TRANSCRIPT="${2:-}"
      if [ -z "$TRANSCRIPT" ]; then
        echo "ERROR: infra — --replay requires a transcript path" >&2
        usage
        exit 3
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "ERROR: infra — unknown flag: $1" >&2
      usage
      exit 3
      ;;
    *)
      if [ -z "$SCENARIO" ]; then
        SCENARIO="$1"
        shift
      else
        echo "ERROR: infra — unexpected positional arg: $1" >&2
        usage
        exit 3
      fi
      ;;
  esac
done

if [ -z "$SCENARIO" ]; then
  echo "ERROR: infra — scenario path is required" >&2
  usage
  exit 3
fi

# ---------------------------------------------------------------------------
# Preflight: jq must be available (Plan v2 Prerequisites)
# ---------------------------------------------------------------------------
if ! command -v jq > /dev/null 2>&1; then
  echo "ERROR: infra — jq >= 1.6 is required on PATH" >&2
  exit 3
fi

# ---------------------------------------------------------------------------
# Load and validate scenario (may exit 3 on schema violation)
# ---------------------------------------------------------------------------
SCENARIO_JSON=$(bash "$LOADER" "$SCENARIO") || exit $?

EXPECTED=$(printf '%s' "$SCENARIO_JSON" | jq -c '.expected_skills')
FORBIDDEN=$(printf '%s' "$SCENARIO_JSON" | jq -c '.forbidden_skills')
MATCH_MODE=$(printf '%s' "$SCENARIO_JSON" | jq -r '.match_mode')
TIMEOUT_SECS=$(printf '%s' "$SCENARIO_JSON" | jq -r '.timeout')
PROMPT=$(printf '%s' "$SCENARIO_JSON" | jq -r '.prompt')
MODEL=$(printf '%s' "$SCENARIO_JSON" | jq -r '.model // empty')

# ---------------------------------------------------------------------------
# Replay mode — no claude invocation, parser + assertion only
# ---------------------------------------------------------------------------
run_replay() {
  local transcript="$1"
  if [ ! -f "$transcript" ]; then
    echo "ERROR: infra — transcript not found: $transcript" >&2
    return 3
  fi
  echo "[replay] parsing $transcript" >&2
  local observed
  observed=$(bash "$PARSER" "$transcript")
  local parse_status=$?
  if [ $parse_status -ne 0 ]; then
    # parser already emitted a diagnostic; normalize to exit 2 (parse_error)
    return 2
  fi

  echo "[replay] asserting mode=$MATCH_MODE expected=$EXPECTED forbidden=$FORBIDDEN" >&2
  bash "$ASSERT" \
    --mode "$MATCH_MODE" \
    --expected "$EXPECTED" \
    --forbidden "$FORBIDDEN" \
    --observed "$observed"
  local assert_status=$?
  case $assert_status in
    0) echo "[replay] PASS (transcript=$transcript)" >&2 ; return 0 ;;
    1) echo "[replay] FAIL (transcript=$transcript)" >&2 ; return 1 ;;
    3) echo "[replay] infra error in assertion engine" >&2 ; return 3 ;;
    *) echo "[replay] unexpected assertion exit $assert_status" >&2 ; return 3 ;;
  esac
}

# ---------------------------------------------------------------------------
# Live mode — run claude -p, capture stdout, then parser + assertion
# ---------------------------------------------------------------------------
CLAUDE_BIN="${HEADLESS_CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"
TMPDIR_OVERRIDE="${HEADLESS_TEMP_DIR:-}"
CLAUDE_PID=""
TEMPDIR_CREATED=""
TRANSCRIPT_OUT=""

cleanup() {
  if [ -n "$CLAUDE_PID" ] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
    kill "$CLAUDE_PID" 2>/dev/null || true
    # give it a moment, then force
    sleep 0.2 2>/dev/null || true
    kill -9 "$CLAUDE_PID" 2>/dev/null || true
  fi
  if [ -n "$TEMPDIR_CREATED" ] && [ -d "$TEMPDIR_CREATED" ]; then
    rm -rf "$TEMPDIR_CREATED"
  fi
}

on_interrupt() {
  local sig="$1"
  echo "[live] received $sig — cleaning up" >&2
  cleanup
  case "$sig" in
    INT)  exit 130 ;;
    TERM) exit 143 ;;
    *)    exit 1 ;;
  esac
}

trap 'on_interrupt INT' INT
trap 'on_interrupt TERM' TERM

run_live() {
  if [ -z "$CLAUDE_BIN" ] || [ ! -x "$CLAUDE_BIN" ]; then
    echo "ERROR: infra — claude binary not found or not executable (HEADLESS_CLAUDE_BIN=$CLAUDE_BIN)" >&2
    return 3
  fi

  if [ -n "$TMPDIR_OVERRIDE" ]; then
    mkdir -p "$TMPDIR_OVERRIDE"
    TEMPDIR_CREATED="$TMPDIR_OVERRIDE"
  else
    TEMPDIR_CREATED=$(mktemp -d "${TMPDIR:-/tmp}/headless-XXXXXX")
  fi
  TRANSCRIPT_OUT="${TEMPDIR_CREATED}/transcript.jsonl"

  echo "[live] invoking $CLAUDE_BIN (timeout=${TIMEOUT_SECS}s, model=${MODEL:-default})" >&2
  echo "[live] transcript -> $TRANSCRIPT_OUT" >&2

  # Build claude args
  local args=(-p --output-format stream-json --include-partial-messages)
  if [ -n "$MODEL" ]; then
    args+=(--model "$MODEL")
  fi
  args+=("$PROMPT")

  # Launch claude; capture stdout to transcript file. Use background to allow SIGINT cleanup.
  "$CLAUDE_BIN" "${args[@]}" > "$TRANSCRIPT_OUT" &
  CLAUDE_PID=$!

  # Poll for completion with a wall-clock timeout
  local elapsed=0
  local step=1
  while kill -0 "$CLAUDE_PID" 2>/dev/null; do
    if [ "$elapsed" -ge "$TIMEOUT_SECS" ]; then
      echo "ERROR: timeout — claude exceeded ${TIMEOUT_SECS}s, killing pid=$CLAUDE_PID" >&2
      kill "$CLAUDE_PID" 2>/dev/null || true
      sleep 0.2 2>/dev/null || true
      kill -9 "$CLAUDE_PID" 2>/dev/null || true
      wait "$CLAUDE_PID" 2>/dev/null || true
      rm -rf "$TEMPDIR_CREATED"
      TEMPDIR_CREATED=""
      return 4
    fi
    sleep "$step"
    elapsed=$((elapsed + step))
  done

  local claude_status=0
  wait "$CLAUDE_PID" 2>/dev/null || claude_status=$?
  CLAUDE_PID=""

  if [ "$claude_status" -ne 0 ]; then
    echo "ERROR: infra — claude exited non-zero ($claude_status)" >&2
    rm -rf "$TEMPDIR_CREATED"
    TEMPDIR_CREATED=""
    return 3
  fi

  echo "[live] parsing transcript" >&2
  local observed
  observed=$(bash "$PARSER" "$TRANSCRIPT_OUT")
  local parse_status=$?
  if [ $parse_status -ne 0 ]; then
    rm -rf "$TEMPDIR_CREATED"
    TEMPDIR_CREATED=""
    return 2
  fi

  echo "[live] asserting mode=$MATCH_MODE" >&2
  bash "$ASSERT" \
    --mode "$MATCH_MODE" \
    --expected "$EXPECTED" \
    --forbidden "$FORBIDDEN" \
    --observed "$observed"
  local assert_status=$?
  # Preserve transcript on failure for debugging
  case $assert_status in
    0)
      echo "[live] PASS" >&2
      rm -rf "$TEMPDIR_CREATED"
      TEMPDIR_CREATED=""
      return 0
      ;;
    1)
      echo "[live] FAIL (transcript kept at $TRANSCRIPT_OUT)" >&2
      return 1
      ;;
    3)
      echo "[live] infra error (transcript at $TRANSCRIPT_OUT)" >&2
      return 3
      ;;
    *)
      return 3
      ;;
  esac
}

if [ "$MODE" = "replay" ]; then
  run_replay "$TRANSCRIPT"
  exit $?
else
  run_live
  exit $?
fi
