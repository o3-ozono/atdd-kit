#!/usr/bin/env bash
# fast-plan-skill-keywords.sh -- AC1 fast PASS
# Verifies that skills/plan/SKILL.md contains required anchors in ascending line-number order.
# Fast layer: no LLM invocation, no fixture. Uses grep -n line-number comparison.
#
# Anchor order required:
#   HARD-GATE → AUTOPILOT-GUARD → State Gate → Core Flow
#   → ### Step 1 → ### Step 2 → ### Step 3 → ### Step 4 → ### Step 5 → ### Step 6

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SKILL_TEST_REPO_ROOT:-${SCRIPT_DIR}/../../..}" && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/plan/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  echo "Error: skill file not found: $SKILL_FILE" >&2
  exit 3
fi

# get_line_number <literal_pattern>
# Returns the first line number matching the pattern, or 0 if not found.
get_line_number() {
  local pattern="$1"
  local lineno
  lineno=$(grep -nF "$pattern" "$SKILL_FILE" | head -1 | cut -d: -f1)
  echo "${lineno:-0}"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Collect line numbers for each anchor
ln_hard_gate=$(get_line_number "<HARD-GATE>")
ln_autopilot_guard=$(get_line_number "<AUTOPILOT-GUARD>")
ln_state_gate=$(get_line_number "State Gate")
ln_core_flow=$(get_line_number "## Core Flow")
ln_step1=$(get_line_number "### Step 1")
ln_step2=$(get_line_number "### Step 2")
ln_step3=$(get_line_number "### Step 3")
ln_step4=$(get_line_number "### Step 4")
ln_step5=$(get_line_number "### Step 5")
ln_step6=$(get_line_number "### Step 6")

# Assert all anchors are present (line number > 0)
for name_val in \
  "HARD-GATE:$ln_hard_gate" \
  "AUTOPILOT-GUARD:$ln_autopilot_guard" \
  "State Gate:$ln_state_gate" \
  "Core Flow:$ln_core_flow" \
  "Step 1:$ln_step1" \
  "Step 2:$ln_step2" \
  "Step 3:$ln_step3" \
  "Step 4:$ln_step4" \
  "Step 5:$ln_step5" \
  "Step 6:$ln_step6"; do
  name="${name_val%%:*}"
  val="${name_val##*:}"
  if [ "$val" -eq 0 ]; then
    fail "anchor '$name' not found in $SKILL_FILE"
  fi
done

# Assert ascending order (9 consecutive comparisons)
[ "$ln_hard_gate"       -lt "$ln_autopilot_guard" ] || fail "HARD-GATE ($ln_hard_gate) must appear before AUTOPILOT-GUARD ($ln_autopilot_guard)"
[ "$ln_autopilot_guard" -lt "$ln_state_gate"       ] || fail "AUTOPILOT-GUARD ($ln_autopilot_guard) must appear before State Gate ($ln_state_gate)"
[ "$ln_state_gate"      -lt "$ln_core_flow"        ] || fail "State Gate ($ln_state_gate) must appear before Core Flow ($ln_core_flow)"
[ "$ln_core_flow"       -lt "$ln_step1"            ] || fail "Core Flow ($ln_core_flow) must appear before Step 1 ($ln_step1)"
[ "$ln_step1"           -lt "$ln_step2"            ] || fail "Step 1 ($ln_step1) must appear before Step 2 ($ln_step2)"
[ "$ln_step2"           -lt "$ln_step3"            ] || fail "Step 2 ($ln_step2) must appear before Step 3 ($ln_step3)"
[ "$ln_step3"           -lt "$ln_step4"            ] || fail "Step 3 ($ln_step3) must appear before Step 4 ($ln_step4)"
[ "$ln_step4"           -lt "$ln_step5"            ] || fail "Step 4 ($ln_step4) must appear before Step 5 ($ln_step5)"
[ "$ln_step5"           -lt "$ln_step6"            ] || fail "Step 5 ($ln_step5) must appear before Step 6 ($ln_step6)"

echo "PASS: fast-plan-skill-keywords (all anchors present in correct order)"
exit 0
