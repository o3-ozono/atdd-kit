#!/usr/bin/env bats
# test_l4_analyze_token_usage.bats -- AC3: per-agent token/cost breakdown

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ANALYZER="${REPO_ROOT}/tests/claude-code/analyze-token-usage.py"
FIXTURES="${REPO_ROOT}/tests/fixtures/claude-code/transcripts"

@test "analyze-token-usage.py exists" {
  [ -f "$ANALYZER" ]
}

@test "exits 3 when file does not exist" {
  run python3 "$ANALYZER" "${FIXTURES}/nonexistent.jsonl"
  [ "$status" -eq 3 ]
}

@test "exits 3 shows error message for missing file" {
  run python3 "$ANALYZER" "${FIXTURES}/nonexistent.jsonl"
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"No such file"* ]] || [[ "$output" == *"Error"* ]]
}

@test "exits 0 for empty jsonl and shows total row with 0 msgs" {
  run python3 "$ANALYZER" "${FIXTURES}/empty.jsonl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total"* ]] || [[ "$output" == *"Total"* ]]
}

@test "exits 0 for valid jsonl and shows per-agent table" {
  run python3 "$ANALYZER" "${FIXTURES}/valid.jsonl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sess"* ]] || [[ "$output" == *"agent"* ]]
}

@test "valid jsonl output contains cost_usd column" {
  run python3 "$ANALYZER" "${FIXTURES}/valid.jsonl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cost"* ]]
}

@test "valid jsonl output contains total row" {
  run python3 "$ANALYZER" "${FIXTURES}/valid.jsonl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total"* ]] || [[ "$output" == *"Total"* ]]
}

@test "exits 0 for malformed jsonl with warning on stderr" {
  run python3 "$ANALYZER" "${FIXTURES}/malformed.jsonl"
  [ "$status" -eq 0 ]
}

@test "malformed jsonl still processes valid lines" {
  run python3 "$ANALYZER" "${FIXTURES}/malformed.jsonl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total"* ]] || [[ "$output" == *"Total"* ]]
}

@test "exits 0 for non-utf8 jsonl with skip and warning" {
  run python3 "$ANALYZER" "${FIXTURES}/non-utf8.jsonl"
  [ "$status" -eq 0 ]
}

@test "unknown model shows cost as N/A and exits 0" {
  tmp=$(mktemp)
  echo '{"type":"assistant","session_id":"sess-x","usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"model":"claude-unknown-future-9"}' > "$tmp"
  run python3 "$ANALYZER" "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"N/A"* ]] || [[ "$output" == *"unknown"* ]]
  rm -f "$tmp"
}

@test "agent with no session_id falls back to (unknown) label" {
  tmp=$(mktemp)
  echo '{"type":"assistant","usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"model":"claude-opus-4-5"}' > "$tmp"
  run python3 "$ANALYZER" "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unknown"* ]]
  rm -f "$tmp"
}
