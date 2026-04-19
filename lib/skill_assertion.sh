#!/usr/bin/env bash
# skill_assertion.sh -- subsequence / strict / forbidden match engine
# Issue #72 / AC4
#
# Usage:
#   bash lib/skill_assertion.sh \
#     --mode <subsequence|strict> \
#     --expected <json-array-of-skill-names> \
#     --forbidden <json-array-of-skill-names> \
#     --observed <json-array-of-{name,args,order}>
#
# Semantics:
#   - subsequence: expected must appear as an ordered subsequence of observed names.
#                  intermediate skills are allowed. Duplicate observed names are matched
#                  greedily (first occurrence consumes the pending expected entry).
#   - strict:      observed names must equal expected exactly (same sequence, no extras).
#   - forbidden:   if any observed name is in the forbidden set, FAIL regardless of mode.
#
# Exit codes:
#   0 — PASS
#   1 — assertion FAIL
#   3 — infra / usage error (invalid --mode, malformed JSON, missing flag)

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: bash lib/skill_assertion.sh \
  --mode <subsequence|strict> \
  --expected <json-array> \
  --forbidden <json-array> \
  --observed <json-array>

Exit codes: 0 PASS, 1 FAIL, 3 infra/usage.
EOF
}

MODE=""
EXPECTED=""
FORBIDDEN=""
OBSERVED=""

while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --expected) EXPECTED="${2:-}"; shift 2 ;;
    --forbidden) FORBIDDEN="${2:-}"; shift 2 ;;
    --observed) OBSERVED="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "ERROR: infra — unknown argument: $1" >&2
      usage
      exit 3
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

if [ -z "$MODE" ] || [ -z "$EXPECTED" ] || [ -z "$FORBIDDEN" ] || [ -z "$OBSERVED" ]; then
  echo "ERROR: infra — --mode, --expected, --forbidden, --observed are all required." >&2
  usage
  exit 3
fi

case "$MODE" in
  subsequence|strict) ;;
  *)
    echo "ERROR: infra — invalid --mode '$MODE' (allowed: subsequence, strict)." >&2
    exit 3
    ;;
esac

# Validate each arg parses as a JSON array
for pair in "expected:$EXPECTED" "forbidden:$FORBIDDEN" "observed:$OBSERVED"; do
  label="${pair%%:*}"
  value="${pair#*:}"
  if ! printf '%s' "$value" | jq -e 'type == "array"' > /dev/null 2>&1; then
    echo "ERROR: infra — --$label is not a valid JSON array" >&2
    exit 3
  fi
done

# ---------------------------------------------------------------------------
# Extract observed names in order
# ---------------------------------------------------------------------------
OBSERVED_NAMES=$(printf '%s' "$OBSERVED" | jq -c '[ .[] | .name ]')

# ---------------------------------------------------------------------------
# Forbidden check
# ---------------------------------------------------------------------------
FORBIDDEN_HITS=$(jq -c -n \
  --argjson forbidden "$FORBIDDEN" \
  --argjson observed "$OBSERVED_NAMES" \
  '[ $observed[] | select(. as $n | $forbidden | index($n)) ]')

if [ "$(printf '%s' "$FORBIDDEN_HITS" | jq 'length')" -gt 0 ]; then
  echo "FAIL: forbidden skill(s) present in observed: $FORBIDDEN_HITS"
  echo "expected=$EXPECTED"
  echo "forbidden=$FORBIDDEN"
  echo "observed=$OBSERVED_NAMES"
  exit 1
fi

# ---------------------------------------------------------------------------
# Mode matching
# ---------------------------------------------------------------------------

if [ "$MODE" = "strict" ]; then
  if [ "$(printf '%s' "$OBSERVED_NAMES" | jq -c '.')" = "$(printf '%s' "$EXPECTED" | jq -c '.')" ]; then
    exit 0
  fi
  echo "FAIL: strict mode — observed does not equal expected"
  echo "expected=$(printf '%s' "$EXPECTED" | jq -c '.')"
  echo "observed=$OBSERVED_NAMES"
  exit 1
fi

# subsequence mode
# Greedy walk: for each expected item, consume observed names until a match is
# found; if we run out of observed names, FAIL.
MATCH_RESULT=$(jq -n \
  --argjson expected "$EXPECTED" \
  --argjson observed "$OBSERVED_NAMES" '
  def walk(exp; obs):
    if (exp | length) == 0 then
      { matched: true, remaining_expected: [] }
    elif (obs | length) == 0 then
      { matched: false, remaining_expected: exp }
    elif obs[0] == exp[0] then
      walk(exp[1:]; obs[1:])
    else
      walk(exp; obs[1:])
    end;
  walk($expected; $observed)
')

if [ "$(printf '%s' "$MATCH_RESULT" | jq -r '.matched')" = "true" ]; then
  exit 0
fi

MISSING=$(printf '%s' "$MATCH_RESULT" | jq -c '.remaining_expected')
echo "FAIL: subsequence mode — expected skills not fully observed"
echo "expected=$EXPECTED"
echo "observed=$OBSERVED_NAMES"
echo "missing=$MISSING"
exit 1
