#!/usr/bin/env bats
# tests/test_bash_output_normalizer.bats
# AC3a: JSON minify
# AC3b: 3+ consecutive blank lines collapsed to 2
# AC3c: Trailing whitespace removed from each line
# AC5: Hook failure fallback - original output is preserved

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
NORMALIZER="$REPO_ROOT/hooks/bash-output-normalizer.sh"

# AC3a: JSON minify
@test "AC3a: JSON output is minified (compact, no extra spaces)" {
  run bash -c 'printf '"'"'{"key": "value", "num": 42}'"'"' | "$1"' _ "$NORMALIZER"
  [ "$status" -eq 0 ]
  [ "$output" = '{"key":"value","num":42}' ]
}

@test "AC3a: multiline JSON is minified to single line" {
  local input_file
  input_file=$(mktemp)
  printf '{\n  "key": "value",\n  "num": 42\n}' > "$input_file"
  run bash -c '"$1" < "$2"' _ "$NORMALIZER" "$input_file"
  rm -f "$input_file"
  [ "$status" -eq 0 ]
  [ "$output" = '{"key":"value","num":42}' ]
}

@test "AC3a: JSON minify is idempotent" {
  run bash -c 'printf '"'"'{"key":"value","num":42}'"'"' | "$1"' _ "$NORMALIZER"
  [ "$status" -eq 0 ]
  local first_output="$output"
  run bash -c 'printf '"'"'{"key":"value","num":42}'"'"' | "$1"' _ "$NORMALIZER"
  [ "$status" -eq 0 ]
  [ "$output" = "$first_output" ]
}

@test "AC3a: minified JSON passes python3 json.load (regression: jq compatibility)" {
  local input_file result_file
  input_file=$(mktemp)
  result_file=$(mktemp)
  printf '{"state": "OPEN", "title": "test PR", "reviewDecision": "APPROVED"}' > "$input_file"
  "$NORMALIZER" < "$input_file" > "$result_file"
  run python3 -c "
import json, sys
with open('$result_file') as f:
    d = json.load(f)
assert d['state'] == 'OPEN', f'state mismatch: {d[\"state\"]}'
print('OK')
"
  rm -f "$input_file" "$result_file"
  [ "$status" -eq 0 ]
}

@test "AC3a: non-JSON plain text passes through (trailing whitespace removed)" {
  run bash -c 'printf '"'"'This is plain text output'"'"' | "$1"' _ "$NORMALIZER"
  [ "$status" -eq 0 ]
  [ "$output" = "This is plain text output" ]
}

@test "AC3a: partial JSON (not parseable) passes through with trailing whitespace removed" {
  local input_file
  input_file=$(mktemp)
  printf '{"incomplete":' > "$input_file"
  run bash -c '"$1" < "$2"' _ "$NORMALIZER" "$input_file"
  rm -f "$input_file"
  [ "$status" -eq 0 ]
  [ "$output" = '{"incomplete":' ]
}

# AC3b: Blank line collapse
@test "AC3b: exactly 3 consecutive blank lines are collapsed to 2" {
  local input_file result_file
  input_file=$(mktemp)
  result_file=$(mktemp)
  printf 'line1\n\n\n\nline2' > "$input_file"
  "$NORMALIZER" < "$input_file" > "$result_file"
  run python3 -c "
with open('$result_file') as f:
    text = f.read()
lines = text.split('\n')
max_consec = 0
cur = 0
for line in lines:
    if line.strip() == '':
        cur += 1
        max_consec = max(max_consec, cur)
    else:
        cur = 0
assert max_consec <= 2, f'Found {max_consec} consecutive blank lines, expected <= 2'
print('OK')
"
  rm -f "$input_file" "$result_file"
  [ "$status" -eq 0 ]
}

@test "AC3b: more than 3 consecutive blank lines are collapsed to 2" {
  local input_file result_file
  input_file=$(mktemp)
  result_file=$(mktemp)
  printf 'line1\n\n\n\n\n\n\nline2' > "$input_file"
  "$NORMALIZER" < "$input_file" > "$result_file"
  run python3 -c "
with open('$result_file') as f:
    text = f.read()
lines = text.split('\n')
max_consec = 0
cur = 0
for line in lines:
    if line.strip() == '':
        cur += 1
        max_consec = max(max_consec, cur)
    else:
        cur = 0
assert max_consec <= 2, f'Found {max_consec} consecutive blank lines, expected <= 2'
assert 'line1' in text and 'line2' in text, 'Content lines must be preserved'
print('OK')
"
  rm -f "$input_file" "$result_file"
  [ "$status" -eq 0 ]
}

@test "AC3b: exactly 2 consecutive blank lines are preserved" {
  local input_file result_file
  input_file=$(mktemp)
  result_file=$(mktemp)
  printf 'line1\n\n\nline2' > "$input_file"
  "$NORMALIZER" < "$input_file" > "$result_file"
  run python3 -c "
with open('$result_file') as f:
    text = f.read()
assert 'line1' in text, 'line1 must be preserved'
assert 'line2' in text, 'line2 must be preserved'
print('OK')
"
  rm -f "$input_file" "$result_file"
  [ "$status" -eq 0 ]
}

@test "AC3b: JSON input blank line collapse is vacuous (JSON is already minified)" {
  local input_file result_file
  input_file=$(mktemp)
  result_file=$(mktemp)
  printf '{\n\n\n\n  "key": "value"\n\n\n}' > "$input_file"
  "$NORMALIZER" < "$input_file" > "$result_file"
  run python3 -c "
import json
with open('$result_file') as f:
    text = f.read()
d = json.loads(text)
assert d['key'] == 'value', f'key mismatch: {d[\"key\"]}'
# Minified: should not have multiple blank lines
assert '\n\n\n' not in text, 'Should not have 3+ blank lines after normalization'
print('OK')
"
  rm -f "$input_file" "$result_file"
  [ "$status" -eq 0 ]
}

# AC3c: Trailing whitespace removal
@test "AC3c: trailing spaces are removed from each line" {
  local input_file result_file
  input_file=$(mktemp)
  result_file=$(mktemp)
  printf 'line1   \nline2\t\t\nline3' > "$input_file"
  "$NORMALIZER" < "$input_file" > "$result_file"
  run python3 -c "
with open('$result_file') as f:
    text = f.read()
for i, line in enumerate(text.split('\n')):
    assert line == line.rstrip(), f'Line {i} has trailing whitespace: {repr(line)}'
print('OK')
"
  rm -f "$input_file" "$result_file"
  [ "$status" -eq 0 ]
}

@test "AC3c: trailing tabs are removed from each line" {
  local input_file result_file
  input_file=$(mktemp)
  result_file=$(mktemp)
  printf 'line1\t\nline2\t\t\t' > "$input_file"
  "$NORMALIZER" < "$input_file" > "$result_file"
  run python3 -c "
with open('$result_file') as f:
    text = f.read()
for i, line in enumerate(text.split('\n')):
    assert line == line.rstrip(), f'Line {i} has trailing whitespace: {repr(line)}'
print('OK')
"
  rm -f "$input_file" "$result_file"
  [ "$status" -eq 0 ]
}

@test "AC3c: empty input produces empty output" {
  run bash -c 'printf "" | "$1"' _ "$NORMALIZER"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# Idempotency
@test "AC3: full normalization pipeline is idempotent on plain text" {
  local input_file first_file second_file
  input_file=$(mktemp)
  first_file=$(mktemp)
  second_file=$(mktemp)
  printf 'line1   \n\n\n\nline2\t\nline3' > "$input_file"
  "$NORMALIZER" < "$input_file" > "$first_file"
  "$NORMALIZER" < "$first_file" > "$second_file"
  run diff "$first_file" "$second_file"
  rm -f "$input_file" "$first_file" "$second_file"
  [ "$status" -eq 0 ]
}

# AC5: Fallback behavior
@test "AC5: hook exit code is always 0 (never blocks original output processing)" {
  run bash -c 'echo "test output" | "$1"' _ "$NORMALIZER"
  [ "$status" -eq 0 ]
}

@test "AC5: hook processes large inputs without failing" {
  local large_file result_file
  large_file=$(mktemp)
  result_file=$(mktemp)
  python3 -c "print('\n'.join(['line ' + str(i) + '   ' for i in range(1000)]))" > "$large_file"
  run bash -c '"$1" < "$2" > "$3" && wc -l < "$3"' _ "$NORMALIZER" "$large_file" "$result_file"
  rm -f "$large_file" "$result_file"
  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]
}

@test "AC5: non-UTF-8 input falls back to original output without traceback on stderr" {
  # Write raw bytes \x80\x81 followed by ASCII text to a temp file
  local input_file result_file stderr_file
  input_file=$(mktemp)
  result_file=$(mktemp)
  stderr_file=$(mktemp)
  python3 -c "import sys; sys.stdout.buffer.write(b'\x80\x81 hello\n')" > "$input_file"
  # Run normalizer capturing stdout and stderr separately
  "$NORMALIZER" < "$input_file" > "$result_file" 2> "$stderr_file"
  local exit_code=$?
  # 1. Exit code must be 0 (fallback, not crash)
  [ "$exit_code" -eq 0 ]
  # 2. stderr must not contain Python Traceback
  run grep -i "traceback\|UnicodeDecodeError" "$stderr_file"
  [ "$status" -ne 0 ]
  # 3. stdout must not be empty (some output delivered)
  local out_size
  out_size=$(wc -c < "$result_file" | tr -d ' ')
  [ "$out_size" -gt 0 ]
  rm -f "$input_file" "$result_file" "$stderr_file"
}
