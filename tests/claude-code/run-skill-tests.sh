#!/usr/bin/env bash
# run-skill-tests.sh -- Fast and integration test runner for skill content tests
#
# Usage:
#   tests/claude-code/run-skill-tests.sh --test <name>                     # fast mode
#   tests/claude-code/run-skill-tests.sh --integration --test <name>       # integration mode
#   tests/claude-code/run-skill-tests.sh --verbose --test <name>           # with invocation echo
#
# Exit codes:
#   0 -- PASS
#   1 -- assertion FAIL
#   3 -- infra error (missing binary, missing test, missing fixture, env error)
#
# Env overrides:
#   SKILL_TEST_CLAUDE_BIN   -- override claude binary path (default: PATH lookup)
#   SKILL_TEST_TMPDIR       -- override transcript output dir (default: ~/.claude/projects/)
#
# Skill E2E Test (single-turn): single-turn claude -p calls, no fixture, no skill chain.
# Skill E2E Test (fixture-based chain): full workflow replay with fixture project + jsonl transcript analysis.
#   Requires python3 for transcript analysis (checked at startup in integration mode).
#
# SIGINT/SIGTERM: kills claude subprocess and removes temp transcript, exits 130/143.

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SAMPLES_DIR="${SCRIPT_DIR}/samples"

MODE="fast"
TEST_NAME=""
VERBOSE=0
CLAUDE_PID=""
TEMP_TRANSCRIPT=""

usage() {
  cat >&2 <<'EOF'
Usage:
  tests/claude-code/run-skill-tests.sh --test <name>
  tests/claude-code/run-skill-tests.sh --integration --test <name>
  tests/claude-code/run-skill-tests.sh --verbose --test <name>

Flags:
  --test <name>     test name to run (required)
  --integration     run in integration mode (requires python3)
  --verbose         echo claude invocation before running

Exit codes: 0 PASS, 1 assertion FAIL, 3 infra error

Env vars:
  SKILL_TEST_CLAUDE_BIN   override claude binary (default: PATH)
  SKILL_TEST_TMPDIR       override transcript dir (default: ~/.claude/projects/)
EOF
}

# Cleanup on SIGINT/SIGTERM
_cleanup() {
  local sig="$1"
  if [ -n "$CLAUDE_PID" ] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
    kill -TERM "-${CLAUDE_PID}" 2>/dev/null || kill -TERM "$CLAUDE_PID" 2>/dev/null || true
  fi
  if [ -n "$TEMP_TRANSCRIPT" ] && [ -f "$TEMP_TRANSCRIPT" ]; then
    rm -f "$TEMP_TRANSCRIPT"
  fi
  if [ "$sig" = "INT" ]; then
    exit 130
  else
    exit 143
  fi
}
trap '_cleanup INT' INT
trap '_cleanup TERM' TERM

# Resolve claude binary
_claude_bin() {
  if [ -n "${SKILL_TEST_CLAUDE_BIN:-}" ]; then
    echo "${SKILL_TEST_CLAUDE_BIN}"
    return
  fi
  if command -v claude > /dev/null 2>&1; then
    echo "claude"
    return
  fi
  echo ""
}

# Arg parsing
if [ $# -eq 0 ]; then
  usage
  exit 3
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --integration)
      MODE="integration"
      shift
      ;;
    --test)
      [ $# -ge 2 ] || { echo "Error: --test requires a name" >&2; usage; exit 3; }
      TEST_NAME="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage
      exit 3
      ;;
  esac
done

if [ -z "$TEST_NAME" ]; then
  echo "Error: --test <name> is required" >&2
  usage
  exit 3
fi

# Check claude binary
CLAUDE_BIN=$(_claude_bin)
if [ -z "$CLAUDE_BIN" ]; then
  echo "Error: claude binary not found; set SKILL_TEST_CLAUDE_BIN or install claude" >&2
  exit 3
fi
if [ ! -x "$CLAUDE_BIN" ] && ! command -v "$CLAUDE_BIN" > /dev/null 2>&1; then
  echo "Error: claude binary not executable: $CLAUDE_BIN" >&2
  exit 3
fi

# Integration mode: check python3
# SKILL_TEST_PYTHON3_BIN allows test override for the python3 presence check
if [ "$MODE" = "integration" ]; then
  _python3_bin="${SKILL_TEST_PYTHON3_BIN:-python3}"
  if ! command -v "$_python3_bin" > /dev/null 2>&1; then
    echo "python3 not found; required for integration layer" >&2
    exit 3
  fi
fi

# Resolve sample script
sample_script=""
if [ "$MODE" = "fast" ]; then
  sample_script="${SAMPLES_DIR}/fast-${TEST_NAME}.sh"
else
  sample_script="${SAMPLES_DIR}/integration-${TEST_NAME}.sh"
fi

if [ ! -f "$sample_script" ]; then
  echo "Error: test '${TEST_NAME}' not found (expected: ${sample_script})" >&2
  exit 3
fi
if [ ! -x "$sample_script" ]; then
  chmod +x "$sample_script"
fi

# Resolve transcript dir
if [ -n "${SKILL_TEST_TMPDIR:-}" ]; then
  TRANSCRIPT_DIR="${SKILL_TEST_TMPDIR}"
else
  # Dynamic resolution: find most recent dir under ~/.claude/projects/
  TRANSCRIPT_DIR=$(ls -td ~/.claude/projects/*/ 2>/dev/null | head -1)
  if [ -z "$TRANSCRIPT_DIR" ]; then
    TRANSCRIPT_DIR=$(mktemp -d)
  fi
fi
mkdir -p "$TRANSCRIPT_DIR"

# Export env for sample scripts to use
export SKILL_TEST_CLAUDE_BIN="$CLAUDE_BIN"
export SKILL_TEST_TMPDIR="$TRANSCRIPT_DIR"
export SKILL_TEST_MODE="$MODE"
export SKILL_TEST_VERBOSE="$VERBOSE"
export SKILL_TEST_REPO_ROOT="$REPO_ROOT"

if [ "$VERBOSE" -eq 1 ]; then
  echo "[run-skill-tests] Executing: $sample_script (mode=$MODE)"
fi

# Run the sample script
bash "$sample_script"
exit_code=$?

if [ "$exit_code" -eq 0 ]; then
  echo "PASS: $TEST_NAME"
else
  echo "FAIL: $TEST_NAME (exit $exit_code)"
fi

exit "$exit_code"
