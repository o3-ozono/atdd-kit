#!/usr/bin/env bats
# @covers: lib/autopilot_convergence.sh
# Unit Test (behavior) for the autopilot convergence safety rails (#246).
# claude is NOT invoked; the bash functions are exercised directly so the
# safety rails (sameness-detector / stuck detection / max-iterations /
# JSONL audit log) are verified by execution, not by grep.

setup() {
  LIB="lib/autopilot_convergence.sh"
  source "$LIB"
  TMP="$(mktemp -d)"
  JSONL="$TMP/autopilot-log.jsonl"
}

teardown() {
  rm -rf "$TMP"
}

# --- fingerprint (normalized sha256) --------------------------------------

@test "fingerprint: identical content yields identical hash, different content differs" {
  a=$(echo "error X failed" | fingerprint)
  b=$(echo "error X failed" | fingerprint)
  c=$(echo "error Y failed" | fingerprint)
  [ -n "$a" ]
  [ "$a" = "$b" ]
  [ "$a" != "$c" ]
}

@test "fingerprint: whitespace jitter is normalized to the same hash" {
  a=$(printf 'error   X\n failed' | fingerprint)
  b=$(printf 'error X failed' | fingerprint)
  [ "$a" = "$b" ]
}

# --- JSONL audit log ------------------------------------------------------

@test "record_iteration: appends one JSONL line with the expected fields" {
  record_iteration "$JSONL" 1 "US" "FAIL" "abc123"
  [ -f "$JSONL" ]
  run cat "$JSONL"
  [[ "$output" == *'"iteration":1'* ]]
  [[ "$output" == *'"step":"US"'* ]]
  [[ "$output" == *'"verdict":"FAIL"'* ]]
  [[ "$output" == *'"fingerprint":"abc123"'* ]]
}

@test "record_iteration: a second call appends (does not overwrite)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  record_iteration "$JSONL" 2 "US" "FAIL" "fp2"
  run wc -l < "$JSONL"
  [ "$(echo "$output" | tr -d ' ')" -eq 2 ]
}

# --- sameness-detector (2 consecutive identical fingerprints halt) --------

@test "check_sameness: two consecutive identical fingerprints halt (non-zero)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "samefp"
  record_iteration "$JSONL" 2 "US" "FAIL" "samefp"
  run check_sameness "$JSONL"
  [ "$status" -ne 0 ]
}

@test "check_sameness: two consecutive different fingerprints continue (zero)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  record_iteration "$JSONL" 2 "US" "FAIL" "fp2"
  run check_sameness "$JSONL"
  [ "$status" -eq 0 ]
}

@test "check_sameness: a single iteration cannot be 'same' (zero)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  run check_sameness "$JSONL"
  [ "$status" -eq 0 ]
}

# --- stuck detection (no progress across a window) ------------------------

@test "check_stuck: window=3 all-identical fingerprints halt (non-zero)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "x"
  record_iteration "$JSONL" 2 "US" "FAIL" "x"
  record_iteration "$JSONL" 3 "US" "FAIL" "x"
  run check_stuck "$JSONL" 3
  [ "$status" -ne 0 ]
}

@test "check_stuck: genuine progress (all-distinct fingerprints) within the window continues" {
  record_iteration "$JSONL" 1 "US" "FAIL" "x"
  record_iteration "$JSONL" 2 "US" "FAIL" "y"
  record_iteration "$JSONL" 3 "US" "FAIL" "z"
  run check_stuck "$JSONL" 3
  [ "$status" -eq 0 ]
}

# A repeat ANYWHERE in the window = revisiting a prior state = no progress.
# This is the non-adjacent duplicate that check_sameness (last-two) misses.
@test "check_stuck: a non-adjacent repeat within the window halts (x,y,x)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "x"
  record_iteration "$JSONL" 2 "US" "FAIL" "y"
  record_iteration "$JSONL" 3 "US" "FAIL" "x"
  run check_stuck "$JSONL" 3
  [ "$status" -ne 0 ]
}

# A,B,A,B oscillation (fix-one / break-another) evades check_sameness because
# the last two are always different; check_stuck must still catch it.
@test "check_stuck: A,B,A,B oscillation halts (regression guard, #246 review)" {
  record_iteration "$JSONL" 1 "plan" "FAIL" "A"
  record_iteration "$JSONL" 2 "plan" "FAIL" "B"
  record_iteration "$JSONL" 3 "plan" "FAIL" "A"
  record_iteration "$JSONL" 4 "plan" "FAIL" "B"
  run check_sameness "$JSONL"
  [ "$status" -eq 0 ]   # sameness (last two A,B differ) does NOT catch it
  run check_stuck "$JSONL" 3
  [ "$status" -ne 0 ]   # stuck DOES catch it (window B,A,B has a repeat)
}

# --- max-iterations -------------------------------------------------------

@test "check_max_iterations: current >= max halts (non-zero)" {
  run check_max_iterations 8 8
  [ "$status" -ne 0 ]
}

@test "check_max_iterations: current < max continues (zero)" {
  run check_max_iterations 3 8
  [ "$status" -eq 0 ]
}

# --- input hardening: the audit log must stay valid + the rails must not go dark

# Round-trip every recorded line through a real JSON parser, not a substring
# match — a substring assertion passes on malformed JSON, hiding injection.
_assert_valid_jsonl() {
  run python3 -c 'import json,sys
[json.loads(l) for l in open(sys.argv[1]) if l.strip()]' "$1"
  [ "$status" -eq 0 ]
}

@test "record_iteration: a double-quote in step/verdict is escaped, log stays valid JSON" {
  record_iteration "$JSONL" 1 'US"evil' 'FAIL"injected' "abc123"
  _assert_valid_jsonl "$JSONL"
  # the quote round-trips as data inside the field, it does not break the JSON
  run python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["verdict"])' "$JSONL"
  [ "$output" = 'FAIL"injected' ]
}

@test "record_iteration: a forged-key injection via step cannot create extra JSON keys" {
  record_iteration "$JSONL" 1 'US","verdict":"PASS","fingerprint":"FORGED' "FAIL" "realfp"
  _assert_valid_jsonl "$JSONL"
  # the real fingerprint is the only one extracted — no FORGED key leaks in
  run _fingerprints "$JSONL"
  [ "$output" = "realfp" ]
}

@test "record_iteration: an empty fingerprint (missing hash tool) is refused, not written dark" {
  run record_iteration "$JSONL" 1 "US" "FAIL" ""
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "record_iteration: a newline-bearing fingerprint is refused (would split the JSONL line)" {
  run record_iteration "$JSONL" 1 "US" "FAIL" "$(printf 'a\nb')"
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "record_iteration: a quote-bearing fingerprint is refused (would break parse/forge)" {
  run record_iteration "$JSONL" 1 "US" "FAIL" 'abc"def'
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "record_iteration: a non-numeric iteration is refused (invalid JSON number)" {
  run record_iteration "$JSONL" "1; rm" "US" "FAIL" "abc123"
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "rails do not go dark: refused records leave no empty-fingerprint line behind" {
  record_iteration "$JSONL" 1 "US" "FAIL" "samefp" || true
  record_iteration "$JSONL" 2 "US" "FAIL" "" || true   # refused — not written
  record_iteration "$JSONL" 3 "US" "FAIL" "samefp" || true
  # only the two valid samefp lines exist, so sameness still fires
  run check_sameness "$JSONL"
  [ "$status" -ne 0 ]
}

# --- round-2 hardening (#246 second review) -------------------------------

@test "record_iteration: a C0 control char (form-feed) in step is collapsed, log stays valid JSON" {
  record_iteration "$JSONL" 1 "$(printf 'US\fevil')" "FAIL" "abc123"
  _assert_valid_jsonl "$JSONL"
}

@test "record_iteration: a backslash-bearing fingerprint is refused" {
  run record_iteration "$JSONL" 1 "US" "FAIL" 'abc\def'
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "record_iteration: a leading-zero iteration is normalized to a valid JSON number" {
  record_iteration "$JSONL" 007 "US" "FAIL" "abc123"
  _assert_valid_jsonl "$JSONL"
  run python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["iteration"])' "$JSONL"
  [ "$output" = "7" ]
}

@test "check_max_iterations: an empty current halts instead of fail-open continue" {
  run check_max_iterations "" 8
  [ "$status" -ne 0 ]
}

@test "check_max_iterations: a non-numeric arg halts" {
  run check_max_iterations "abc" 8
  [ "$status" -ne 0 ]
}

@test "check_stuck: a non-numeric window halts instead of silently disabling the rail" {
  record_iteration "$JSONL" 1 "US" "FAIL" "x"
  record_iteration "$JSONL" 2 "US" "FAIL" "x"
  record_iteration "$JSONL" 3 "US" "FAIL" "x"
  run check_stuck "$JSONL" "3; echo PWNED"
  [ "$status" -ne 0 ]
}

# --- #262: 監査ログ完全一致ガード check_log_integrity（fail-closed） -------
# orchestrator がメモリ上で追跡する期待行数（baseline + 記録数）と、ログの
# 実際の非空行数の完全一致を検証する。不一致 = 削除・巻き戻し・外部追記。

# AT-002: 記録済みのはずのログが消えていたら halt する（run 途中の削除）
@test "check_log_integrity (#262): expected>0 with a missing log halts (mid-run deletion)" {
  run check_log_integrity "$JSONL" 1
  [ "$status" -ne 0 ]
  run check_log_integrity "$JSONL" 5
  [ "$status" -ne 0 ]
}

# AT-003: 行数が期待より少ないログは halt する（truncate / 巻き戻し）
@test "check_log_integrity (#262): actual < expected halts (rollback / truncate)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  record_iteration "$JSONL" 2 "US" "FAIL" "fp2"
  # 3 行記録したはずが 2 行しかない（1 行巻き戻された）
  run check_log_integrity "$JSONL" 3
  [ "$status" -ne 0 ]
  # 全行削除して空ファイルにした truncate も検出する
  : > "$JSONL"
  run check_log_integrity "$JSONL" 2
  [ "$status" -ne 0 ]
}

# AT-004: 行数が期待より多いログは halt する（外部追記 — 完全一致の両方向）
@test "check_log_integrity (#262): actual > expected halts (external append)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  echo '{"iteration":99,"step":"forged","verdict":"PASS","fingerprint":"ff"}' >> "$JSONL"
  run check_log_integrity "$JSONL" 1
  [ "$status" -ne 0 ]
}

# AT-005: expected が空・非数値・コマンド注入文字列なら fail-closed（status 2）
@test "check_log_integrity (#262): an empty expected emits stderr and returns status 2" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  run check_log_integrity "$JSONL" ""
  [ "$status" -eq 2 ]
  [ -n "$output" ]   # レールを黙って無効化しない（check_stuck の window 検証と同等）
}

@test "check_log_integrity (#262): a non-numeric expected returns status 2" {
  run check_log_integrity "$JSONL" "abc"
  [ "$status" -eq 2 ]
}

@test "check_log_integrity (#262): a command-injection expected returns status 2" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  run check_log_integrity "$JSONL" "3; echo PWNED"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid"* ]]   # 検証エラーであり、注入文字列は実行されない
}

# AT-001: 正当な初回（ログ未存在 + expected=0）と行数一致は誤検出ゼロ
@test "check_log_integrity (#262): missing log + expected=0 passes (legitimate first run)" {
  run check_log_integrity "$JSONL" 0
  [ "$status" -eq 0 ]
}

@test "check_log_integrity (#262): actual == expected passes (zero false positives)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  record_iteration "$JSONL" 2 "US" "FAIL" "fp2"
  record_iteration "$JSONL" 3 "US" "PASS" "fp3"
  run check_log_integrity "$JSONL" 3
  [ "$status" -eq 0 ]
}

# --- AL-2 immutable-AC anchor (pin / drift) -------------------------------

@test "pin_anchor + check_pin: unchanged AC passes, drifted AC halts" {
  PIN="$TMP/ac.pin"
  printf 'AC: the approved acceptance criteria\n' | pin_anchor "$PIN"
  [ -s "$PIN" ]
  same=$(printf 'AC: the approved acceptance criteria\n' | fingerprint)
  run check_pin "$PIN" "$same"
  [ "$status" -eq 0 ]                       # unchanged AC → continue
  drifted=$(printf 'AC: the WEAKENED criteria\n' | fingerprint)
  run check_pin "$PIN" "$drifted"
  [ "$status" -ne 0 ]                       # loop edited its own anchor → halt
}

@test "pin_anchor: refuses to overwrite an existing pin (anchor frozen for the run)" {
  PIN="$TMP/ac.pin"
  printf 'AC v1\n' | pin_anchor "$PIN"
  run bash -c "source '$LIB'; printf 'AC v2\n' | pin_anchor '$PIN'"
  [ "$status" -ne 0 ]
}

@test "check_pin: a missing pin halts (cannot prove the anchor)" {
  run check_pin "$TMP/nonexistent.pin" "abc123"
  [ "$status" -ne 0 ]
}

@test "check_pin: an empty current fingerprint halts (cannot prove no-drift)" {
  PIN="$TMP/ac.pin"
  printf 'AC\n' | pin_anchor "$PIN"
  run check_pin "$PIN" ""
  [ "$status" -ne 0 ]
}

# --- #252: placeholder fingerprint regression pin ---------------------------

@test "placeholder fingerprint (#252): the literal placeholder hashes to the incident constant and is absent from the skill (AC5)" {
  # recompute the constant recorded by the #251 incident — pins that THIS string
  # is the bad input the audit prompt must never instruct an agent to hash
  fp=$(printf '%s' "<the blocking findings text, verbatim>" | fingerprint)
  [ "$fp" = "2aed7ea6d4c79d81da29da31fe975d762c64b1e15c211769880c3c6a92ccce2a" ]
  # the instruction path that hashed the placeholder must not exist anymore
  ! grep -qF '<the blocking findings text, verbatim>' "skills/autopilot/SKILL.md"
}
