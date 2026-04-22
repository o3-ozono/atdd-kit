#!/usr/bin/env bats
# @covers: lib/skill_assertion.sh
bats_require_minimum_version 1.5.0

# =============================================================================
# skill_assertion.sh -- Unit tests
# Issue #72: AC4 -- assertion match model (subsequence / strict / forbidden)
#
# Usage:
#   bash lib/skill_assertion.sh --mode <subsequence|strict> \
#     --expected <json-array> \
#     --forbidden <json-array> \
#     --observed <json-array>
#
# Behavior:
#   - subsequence: expected appears as an ordered subsequence of observed (gaps allowed)
#   - strict:      observed equals expected exactly (same items, same order, no extras)
#   - forbidden:   any observed name in forbidden => FAIL regardless of mode
#   - Duplicate-skill in observed: matched against expected greedily (first occurrence consumed,
#     rest treated as intermediate for subsequence; rest count as extras for strict).
#
# Exit codes:
#   0 — PASS (assertion held)
#   1 — assertion FAIL
#   3 — infra / usage (invalid mode, malformed JSON)
# =============================================================================

ASSERT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/lib/skill_assertion.sh"
PARSER="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/lib/skill_transcript_parser.sh"
FIXTURES="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/tests/fixtures/headless"

observed_simple() {
  printf '[{"name":"skill-gate","args":null,"order":1},{"name":"discover","args":null,"order":2}]'
}

run_assert() {
  local mode="$1" expected="$2" forbidden="$3" observed="$4"
  run bash "$ASSERT" \
    --mode "$mode" \
    --expected "$expected" \
    --forbidden "$forbidden" \
    --observed "$observed"
}

# -----------------------------------------------------------------------------
# Subsequence mode
# -----------------------------------------------------------------------------

@test "subsequence: exact match passes" {
  run_assert subsequence '["skill-gate","discover"]' '[]' "$(observed_simple)"
  [ "$status" -eq 0 ]
}

@test "subsequence: extra skills between expected PASS" {
  local obs='[{"name":"skill-gate","args":null,"order":1},{"name":"noise","args":null,"order":2},{"name":"discover","args":null,"order":3}]'
  run_assert subsequence '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 0 ]
}

@test "subsequence: out-of-order FAIL" {
  local obs='[{"name":"discover","args":null,"order":1},{"name":"skill-gate","args":null,"order":2}]'
  run_assert subsequence '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "expected" ]] || [[ "$output" =~ "observed" ]] || [[ "$output" =~ "FAIL" ]]
}

@test "subsequence: missing expected skill FAIL" {
  local obs='[{"name":"skill-gate","args":null,"order":1}]'
  run_assert subsequence '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 1 ]
}

@test "subsequence: empty observed with non-empty expected FAIL" {
  run_assert subsequence '["skill-gate"]' '[]' '[]'
  [ "$status" -eq 1 ]
}

@test "subsequence: empty expected always PASS when no forbidden" {
  run_assert subsequence '[]' '[]' "$(observed_simple)"
  [ "$status" -eq 0 ]
}

# -----------------------------------------------------------------------------
# Strict mode
# -----------------------------------------------------------------------------

@test "strict: exact match PASS" {
  run_assert strict '["skill-gate","discover"]' '[]' "$(observed_simple)"
  [ "$status" -eq 0 ]
}

@test "strict: extra skill between FAILS" {
  local obs='[{"name":"skill-gate","args":null,"order":1},{"name":"noise","args":null,"order":2},{"name":"discover","args":null,"order":3}]'
  run_assert strict '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 1 ]
}

@test "strict: trailing extra skill FAILS" {
  local obs='[{"name":"skill-gate","args":null,"order":1},{"name":"discover","args":null,"order":2},{"name":"plan","args":null,"order":3}]'
  run_assert strict '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 1 ]
}

@test "strict: out-of-order FAILS" {
  local obs='[{"name":"discover","args":null,"order":1},{"name":"skill-gate","args":null,"order":2}]'
  run_assert strict '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 1 ]
}

# -----------------------------------------------------------------------------
# Forbidden
# -----------------------------------------------------------------------------

@test "forbidden: hit in observed causes FAIL (subsequence)" {
  local obs='[{"name":"skill-gate","args":null,"order":1},{"name":"plan","args":null,"order":2},{"name":"discover","args":null,"order":3}]'
  run_assert subsequence '["skill-gate","discover"]' '["plan","atdd"]' "$obs"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "forbidden" ]] || [[ "$output" =~ "plan" ]]
}

@test "forbidden: hit in observed causes FAIL (strict)" {
  local obs='[{"name":"skill-gate","args":null,"order":1},{"name":"plan","args":null,"order":2},{"name":"discover","args":null,"order":3}]'
  run_assert strict '["skill-gate","plan","discover"]' '["plan"]' "$obs"
  [ "$status" -eq 1 ]
}

@test "forbidden: no hit PASSES" {
  run_assert subsequence '["skill-gate","discover"]' '["atdd","verify"]' "$(observed_simple)"
  [ "$status" -eq 0 ]
}

# -----------------------------------------------------------------------------
# Duplicate-skill semantics
# -----------------------------------------------------------------------------

@test "duplicate-skill subsequence: first occurrence consumes expected, rest ignored" {
  local obs='[{"name":"skill-gate","args":null,"order":1},{"name":"skill-gate","args":null,"order":2},{"name":"discover","args":null,"order":3}]'
  run_assert subsequence '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 0 ]
}

@test "duplicate-skill strict: extra occurrence is counted as FAIL" {
  local obs='[{"name":"skill-gate","args":null,"order":1},{"name":"skill-gate","args":null,"order":2},{"name":"discover","args":null,"order":3}]'
  run_assert strict '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 1 ]
}

# -----------------------------------------------------------------------------
# Args with special characters — smoke test that parser->assertion roundtrip is safe
# -----------------------------------------------------------------------------

@test "args-special-chars: observed with quotes/newlines/nested JSON does not break matching" {
  local obs='[{"name":"skill-gate","args":{"q":"hello \"world\"","lines":"a\nb"},"order":1},{"name":"discover","args":{"nested":{"k":1}},"order":2}]'
  run_assert subsequence '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 0 ]
}

# -----------------------------------------------------------------------------
# Error / infra cases
# -----------------------------------------------------------------------------

@test "infra: invalid --mode causes exit 3" {
  run_assert unknown-mode '["x"]' '[]' '[]'
  [ "$status" -eq 3 ]
}

@test "infra: malformed --observed JSON causes exit 3" {
  run bash "$ASSERT" --mode subsequence \
    --expected '["x"]' --forbidden '[]' --observed 'not json'
  [ "$status" -eq 3 ]
}

@test "infra: missing required flag causes exit 3" {
  run bash "$ASSERT" --mode subsequence --expected '[]' --forbidden '[]'
  [ "$status" -eq 3 ]
}

# -----------------------------------------------------------------------------
# Match-edge fixture roundtrip (parser + assertion)
# -----------------------------------------------------------------------------

@test "fixture duplicate-skill.jsonl: subsequence PASS (first occurrence consumed)" {
  local obs
  obs=$(bash "$PARSER" "$FIXTURES/duplicate-skill.jsonl")
  run bash "$ASSERT" --mode subsequence \
    --expected '["atdd-kit:skill-gate","atdd-kit:discover"]' \
    --forbidden '[]' --observed "$obs"
  [ "$status" -eq 0 ]
}

@test "fixture args-special-chars.jsonl: subsequence PASS + args preserved through parser" {
  local obs
  obs=$(bash "$PARSER" "$FIXTURES/args-special-chars.jsonl")
  # parser must preserve the nested args object
  echo "$obs" | jq -e '.[0].args.nested.k == 1' >/dev/null
  run bash "$ASSERT" --mode subsequence \
    --expected '["atdd-kit:skill-gate","atdd-kit:discover"]' \
    --forbidden '[]' --observed "$obs"
  [ "$status" -eq 0 ]
}

@test "FAIL message for subsequence includes expected list and observed list" {
  local obs='[{"name":"discover","args":null,"order":1}]'
  run_assert subsequence '["skill-gate","discover"]' '[]' "$obs"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "skill-gate" ]]
  [[ "$output" =~ "discover" ]]
}
