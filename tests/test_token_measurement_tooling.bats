#!/usr/bin/env bats
# @covers: scripts/measure-token-reduction.sh
# tests/test_token_measurement_tooling.bats
# AC4a: Token reduction measurement tooling exists and works correctly

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MEASURE_SCRIPT="$REPO_ROOT/scripts/measure-token-reduction.sh"
FIXTURES_DIR="$REPO_ROOT/tests/fixtures/token-reduction"

@test "AC4a: measure-token-reduction.sh exists" {
  [ -f "$MEASURE_SCRIPT" ]
}

@test "AC4a: measure-token-reduction.sh is executable" {
  [ -x "$MEASURE_SCRIPT" ]
}

@test "AC4a: tests/fixtures/token-reduction/baseline/ directory exists" {
  [ -d "$FIXTURES_DIR/baseline" ]
}

@test "AC4a: tests/fixtures/token-reduction/after/ directory exists" {
  [ -d "$FIXTURES_DIR/after" ]
}

@test "AC4a: script outputs byte count for known input" {
  local tmpfile
  tmpfile=$(mktemp)
  # 10 bytes
  printf 'hello12345' > "$tmpfile"
  run bash -c '"$1" "$2"' _ "$MEASURE_SCRIPT" "$tmpfile"
  rm -f "$tmpfile"
  [ "$status" -eq 0 ]
  # Output should contain a number
  echo "$output" | grep -E '[0-9]'
  [ "$status" -eq 0 ]
}

@test "AC4a: script outputs reduction rate when given before and after files" {
  local before_file after_file
  before_file=$(mktemp)
  after_file=$(mktemp)
  # before: 100 bytes
  python3 -c "print('x' * 100)" > "$before_file"
  # after: 75 bytes (25% reduction)
  python3 -c "print('x' * 75)" > "$after_file"
  run bash -c '"$1" "$2" "$3"' _ "$MEASURE_SCRIPT" "$before_file" "$after_file"
  rm -f "$before_file" "$after_file"
  [ "$status" -eq 0 ]
  # Output should contain a percentage or reduction info
  echo "$output" | grep -E '[0-9]+(\.[0-9]+)?%|reduction|bytes'
  [ "$status" -eq 0 ]
}

@test "AC4a: script handles multibyte characters (Japanese text)" {
  local tmpfile
  tmpfile=$(mktemp)
  printf 'こんにちは世界' > "$tmpfile"
  run bash -c '"$1" "$2"' _ "$MEASURE_SCRIPT" "$tmpfile"
  rm -f "$tmpfile"
  [ "$status" -eq 0 ]
  # Should output a number (byte count)
  echo "$output" | grep -E '[0-9]'
  [ "$status" -eq 0 ]
}

@test "AC4a: script output includes note about byte-based estimation" {
  local tmpfile
  tmpfile=$(mktemp)
  printf 'test content' > "$tmpfile"
  run bash -c '"$1" "$2" "$2"' _ "$MEASURE_SCRIPT" "$tmpfile"
  rm -f "$tmpfile"
  [ "$status" -eq 0 ]
  # Output should mention bytes or character-based
  echo "$output" | grep -iE 'bytes|char|wc'
  [ "$status" -eq 0 ]
}

@test "AC4a: fixtures baseline contains at least one sample file" {
  local count
  count=$(ls "$FIXTURES_DIR/baseline/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -gt 0 ]
}

@test "AC4a: fixtures after contains at least one sample file" {
  local count
  count=$(ls "$FIXTURES_DIR/after/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -gt 0 ]
}
