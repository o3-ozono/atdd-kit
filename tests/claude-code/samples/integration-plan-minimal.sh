#!/usr/bin/env bash
# integration-plan-minimal.sh -- AC2 integration PASS sample
# Invokes claude -p against the minimal-project fixture with --autopilot to bypass
# AUTOPILOT-GUARD, then verifies the jsonl transcript contains plan deliverable markers.
#
# Guard: requires RUN_INTEGRATION=1 (real LLM, ~$5/run).
# Stub mode: when SKILL_TEST_CLAUDE_BIN is set, transcript parsing is skipped
#            (stub emits no plan content — same pattern as integration-discover-minimal.sh:54).
#
# Skill E2E Test (fixture-based chain): fixture project + jsonl transcript analysis.

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
FIXTURE_DIR="${SCRIPT_DIR}/../fixtures/minimal-project"
ANALYZER="${SCRIPT_DIR}/../analyze-token-usage.py"
CLAUDE_BIN="${SKILL_TEST_CLAUDE_BIN:-claude}"
TMPDIR_BASE="${SKILL_TEST_TMPDIR:-$(mktemp -d)}"
TRANSCRIPT="${TMPDIR_BASE}/integration-plan-minimal.jsonl"

# Guard: skip unless RUN_INTEGRATION=1
if [ "${RUN_INTEGRATION:-0}" != "1" ] && [ -z "${SKILL_TEST_CLAUDE_BIN:-}" ]; then
  echo "SKIP: integration-plan-minimal (set RUN_INTEGRATION=1 to run)"
  exit 0
fi

if [ ! -d "$FIXTURE_DIR" ]; then
  echo "Error: fixture project not found: $FIXTURE_DIR" >&2
  exit 3
fi

if [ ! -x "$CLAUDE_BIN" ] && ! command -v "$CLAUDE_BIN" > /dev/null 2>&1; then
  echo "Error: claude binary not found: $CLAUDE_BIN" >&2
  exit 3
fi

# Invoke claude -p with --autopilot in prompt to bypass AUTOPILOT-GUARD and State Gate.
# The prompt asks the skill to run in a context where discover deliverables are provided inline.
PROMPT="You are running atdd-kit:plan --autopilot for a test project. Inline mode: the discover deliverables are already in context. Produce a minimal Implementation Plan with a Test Strategy section and an Implementation Strategy section. Output the plan as markdown."

"$CLAUDE_BIN" -p "$PROMPT" \
  --permission-mode bypassPermissions \
  --add-dir "$FIXTURE_DIR" \
  --output-format stream-json \
  --no-interactive \
  2>/dev/null > "$TRANSCRIPT" || true

# Stub mode: stub may have written to SKILL_TEST_TMPDIR
if [ ! -s "$TRANSCRIPT" ]; then
  stub_transcript="${TMPDIR_BASE}/stub-transcript.jsonl"
  if [ -f "$stub_transcript" ]; then
    cp "$stub_transcript" "$TRANSCRIPT"
  fi
fi

# Stub mode detection: skip content assertions unless RUN_INTEGRATION=1 with real claude.
# runner always exports SKILL_TEST_CLAUDE_BIN, so :+1 alone would mark every runner invocation
# as stub even when real LLM is intended. Real mode requires RUN_INTEGRATION=1 AND
# SKILL_TEST_CLAUDE_BIN unset or equal to "claude" (PATH lookup).
if [ "${RUN_INTEGRATION:-0}" = "1" ] && { [ -z "${SKILL_TEST_CLAUDE_BIN:-}" ] || [ "${SKILL_TEST_CLAUDE_BIN}" = "claude" ]; }; then
  IS_STUB=""
else
  IS_STUB="${SKILL_TEST_CLAUDE_BIN:+1}"
fi

# Verify transcript is parseable
if python3 "$ANALYZER" "$TRANSCRIPT" > /dev/null 2>&1; then
  if [ -n "$IS_STUB" ]; then
    echo "PASS: integration-plan-minimal (stub mode, transcript parseable)"
    exit 0
  fi
  # Real LLM mode: assert deliverable markers are present in transcript
  raw_text=$(python3 -c "
import json, sys
texts = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        # Extract text from assistant message content
        if obj.get('type') == 'assistant':
            for block in obj.get('message', {}).get('content', []):
                if isinstance(block, dict) and block.get('type') == 'text':
                    texts.append(block.get('text', ''))
        # Also capture result text
        if obj.get('type') == 'result':
            texts.append(obj.get('result', ''))
    except (json.JSONDecodeError, KeyError, TypeError):
        pass
print('\n'.join(texts))
" < "$TRANSCRIPT")

  has_impl_plan=$(echo "$raw_text" | grep -c "## Implementation Plan" || true)
  has_test_strategy=$(echo "$raw_text" | grep -c "### Test Strategy" || true)

  if [ "$has_impl_plan" -ge 1 ] && [ "$has_test_strategy" -ge 1 ]; then
    echo "PASS: integration-plan-minimal (transcript parseable, deliverable markers found)"
    exit 0
  else
    echo "FAIL: expected '## Implementation Plan' (found: $has_impl_plan) and '### Test Strategy' (found: $has_test_strategy) in transcript" >&2
    exit 1
  fi
else
  if [ ! -f "$TRANSCRIPT" ]; then
    if [ -n "$IS_STUB" ]; then
      echo "PASS: integration-plan-minimal (stub mode, no transcript expected)"
      exit 0
    fi
    echo "FAIL: transcript file not created" >&2
    exit 1
  fi
  echo "FAIL: transcript not parseable by analyze-token-usage.py" >&2
  exit 1
fi
