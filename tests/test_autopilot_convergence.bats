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

# --- #248: audit-log corruption guard (AL-4 completeness) -----------------
# _fingerprints must never SILENTLY drop a FAIL row whose fingerprint was
# partial-written / externally corrupted: dropping it erases a stuck/sameness
# data point (fail-OPEN). The guard demands FAIL-row-count == fingerprint-count
# and returns non-zero so the rails escalate (halt) instead of going dark.

@test "#248 corruption: a FAIL row with a truncated fingerprint halts check_sameness (not dark)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "samefp"
  # simulate a partial write: a FAIL row whose fingerprint field has no value
  printf '%s\n' '{"iteration":2,"step":"US","verdict":"FAIL","fingerprint":"' >> "$JSONL"
  run check_sameness "$JSONL"
  [ "$status" -ne 0 ]
}

@test "#248 corruption: a FAIL row missing the fingerprint key halts check_stuck (not dark)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "a"
  record_iteration "$JSONL" 2 "US" "FAIL" "b"
  printf '%s\n' '{"iteration":3,"step":"US","verdict":"FAIL"}' >> "$JSONL"
  run check_stuck "$JSONL" 3
  [ "$status" -ne 0 ]
}

@test "#248 corruption: _fingerprints returns non-zero when a FAIL row yields no fingerprint" {
  record_iteration "$JSONL" 1 "US" "FAIL" "okfp"
  printf '%s\n' '{"iteration":2,"step":"US","verdict":"FAIL","fingerprint":""}' >> "$JSONL"
  run _fingerprints "$JSONL"
  [ "$status" -ne 0 ]
}

@test "#248 corruption: detected within a step-scoped population" {
  record_iteration "$JSONL" 1 "running-atdd-cycle" "FAIL" "okfp"
  printf '%s\n' '{"iteration":2,"step":"running-atdd-cycle","verdict":"FAIL","fingerprint":""}' >> "$JSONL"
  run check_sameness "$JSONL" "running-atdd-cycle"
  [ "$status" -ne 0 ]
}

@test "#248 corruption: a malformed PASS row does NOT trigger the guard (PASS excluded, #277)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "a"
  record_iteration "$JSONL" 2 "US" "FAIL" "a"
  # a corrupt PASS row is outside the FAIL-only population — must not false-halt
  printf '%s\n' '{"iteration":3,"step":"US","verdict":"PASS","fingerprint":"' >> "$JSONL"
  run check_sameness "$JSONL"
  # sameness still fires on the two identical FAIL "a" rows; corruption NOT raised
  [ "$status" -eq 1 ]
}

@test "#248 corruption: a clean log is unaffected (no false corruption halt)" {
  record_iteration "$JSONL" 1 "US" "FAIL" "a"
  record_iteration "$JSONL" 2 "US" "FAIL" "b"
  run check_stuck "$JSONL" 3
  [ "$status" -eq 0 ]   # 2 rows < window 3 → continue
  run _fingerprints "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'a\nb')" ]
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

# --- #272: check_sameness / check_stuck の step スコープ化（AT-001〜AT-004） ---
# #269 再現: design phase 最終行と impl iteration 1 が同一 fingerprint でも
# step 引数付き呼び出しでは偽 halt が発生しない。

# 2 step 混在フィクスチャを組み立てるヘルパー:
# - design phase 最終行（step=writing-plan-and-tests, fingerprint=<empty-findings fp>）
# - impl iteration 1（step=running-atdd-cycle, 同じ fingerprint）
_make_cross_step_log() {
  local jsonl="$1"
  # 空 findings の実際の fingerprint を生成する（check_sameness のデフォルト挙動と合わせる）
  local fp
  fp=$(printf '%s' "[]" | fingerprint)
  record_iteration "$jsonl" 1 "writing-plan-and-tests" "PASS" "$fp"
  record_iteration "$jsonl" 2 "running-atdd-cycle"     "FAIL" "$fp"
}

@test "AT-001 (#272): cross-step same fingerprint does not false-halt check_sameness (step arg)" {
  # Given: design phase 最終行 + impl iteration 1 が同一 fingerprint の混在ログ
  _make_cross_step_log "$JSONL"
  # When: check_sameness <log> running-atdd-cycle（#269 再現ケース）
  run check_sameness "$JSONL" "running-atdd-cycle"
  # Then: exit code 0（continue）— 同一 step の行が 1 行しかないため sameness 不成立
  [ "$status" -eq 0 ]
}

@test "AT-002 (#272): same-step consecutive same fingerprint still halts (no regression)" {
  # Given: 同一 step（running-atdd-cycle）の行が連続 2 行、同一 fingerprint
  local fp
  fp=$(printf '%s' "[]" | fingerprint)
  record_iteration "$JSONL" 1 "running-atdd-cycle" "FAIL" "$fp"
  record_iteration "$JSONL" 2 "running-atdd-cycle" "FAIL" "$fp"
  # When: check_sameness <log> running-atdd-cycle
  run check_sameness "$JSONL" "running-atdd-cycle"
  # Then: exit code 非ゼロ（halt）— 同一 step 内の反復停滞は従来どおり検出
  [ "$status" -ne 0 ]
}

@test "AT-003 (#272->#277): legacy mode also applies FAIL-only -- PASS rows are not collision sources (Gate-1 all-mode)" {
  # #277: FAIL-only 適用後の新意味論。_make_cross_step_log は PASS+FAIL 混在ログ
  # （step=writing-plan-and-tests PASS + step=running-atdd-cycle FAIL）。
  # FAIL-only フィルタにより PASS 行は除外され、残る FAIL 行は 1 件のみ → sameness 不成立。
  # Gate-1 承認の全モード適用方針どおり、step 引数省略でも FAIL-only が効く（#277）。
  _make_cross_step_log "$JSONL"
  # When: check_sameness <log> (no step arg)
  run check_sameness "$JSONL"
  # Then: exit code 0 (continue) -- PASS row excluded by FAIL-only, only 1 FAIL row, sameness not met
  [ "$status" -eq 0 ]
}

@test "AT-004a (#272): check_stuck excludes cross-step rows from window population" {
  # Given: 別 step の行を挟み、対象 step（running-atdd-cycle）の fingerprint はすべて異なる
  local fp1 fp2 fp3 fpD
  fp1=$(printf '%s' "fail-A" | fingerprint)
  fp2=$(printf '%s' "fail-B" | fingerprint)
  fp3=$(printf '%s' "fail-C" | fingerprint)
  fpD=$(printf '%s' "[]"     | fingerprint)  # design phase 行の fingerprint
  record_iteration "$JSONL" 1 "running-atdd-cycle"     "FAIL" "$fp1"
  record_iteration "$JSONL" 2 "writing-plan-and-tests" "PASS" "$fpD"  # 別 step
  record_iteration "$JSONL" 3 "running-atdd-cycle"     "FAIL" "$fp2"
  record_iteration "$JSONL" 4 "running-atdd-cycle"     "FAIL" "$fp3"
  # When: check_stuck <log> 3 running-atdd-cycle
  run check_stuck "$JSONL" 3 "running-atdd-cycle"
  # Then: exit code 0（continue）— 対象 step 系列は正当な前進
  [ "$status" -eq 0 ]
}

@test "AT-004b (#272): check_stuck detects same-step flatline (A,A,A) with step arg" {
  # Given: 同一 step の行が window 内で A,A,A
  local fp
  fp=$(printf '%s' "fail-X" | fingerprint)
  record_iteration "$JSONL" 1 "running-atdd-cycle" "FAIL" "$fp"
  record_iteration "$JSONL" 2 "running-atdd-cycle" "FAIL" "$fp"
  record_iteration "$JSONL" 3 "running-atdd-cycle" "FAIL" "$fp"
  # When: check_stuck <log> 3 running-atdd-cycle
  run check_stuck "$JSONL" 3 "running-atdd-cycle"
  # Then: exit code 非ゼロ（halt）— AL-5 の無限ループ防止が維持される
  [ "$status" -ne 0 ]
}

@test "AT-004c (#272): check_stuck detects same-step oscillation (A,B,A) with step arg" {
  # Given: 同一 step の行が window 内で A,B,A（fix-one / break-another）
  local fpA fpB
  fpA=$(printf '%s' "fail-A" | fingerprint)
  fpB=$(printf '%s' "fail-B" | fingerprint)
  record_iteration "$JSONL" 1 "running-atdd-cycle" "FAIL" "$fpA"
  record_iteration "$JSONL" 2 "running-atdd-cycle" "FAIL" "$fpB"
  record_iteration "$JSONL" 3 "running-atdd-cycle" "FAIL" "$fpA"
  # When: check_stuck <log> 3 running-atdd-cycle
  run check_stuck "$JSONL" 3 "running-atdd-cycle"
  # Then: exit code 非ゼロ（halt）
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

# --- #277: sameness/stuck rails の比較母集団を同一 step の FAIL 行のみに絞る ----
# AT-001〜AT-006: 設計ゲート差し戻し再入の偽 halt 修正 / FAIL-only 意味論 pin

@test "AT-001 (#277): same-step [PASS,PASS,FAIL] check_stuck returns continue (no false stuck-halt)" {
  # Given: design-gate re-entry x2 repro -- same step has 2 PASS rows (constant payload = same fp)
  # and 1 FAIL row (#261 incident equivalent).
  # PASS 行は FAIL-only フィルタで除外、FAIL 行 1 件だけでは window=3 不成立 → continue (#277)
  local fp_pass fp_fail
  fp_pass=$(printf '%s' "pass-payload" | fingerprint)
  fp_fail=$(printf '%s' "fail-payload" | fingerprint)
  record_iteration "$JSONL" 1 "running-atdd-cycle" "PASS" "$fp_pass"
  record_iteration "$JSONL" 2 "running-atdd-cycle" "PASS" "$fp_pass"
  record_iteration "$JSONL" 3 "running-atdd-cycle" "FAIL" "$fp_fail"
  # When: check_stuck <log> 3 running-atdd-cycle
  run check_stuck "$JSONL" 3 "running-atdd-cycle"
  # Then: exit code 0 (continue) -- PASS rows excluded by FAIL-only, only 1 FAIL row, window=3 not met
  [ "$status" -eq 0 ]
}

@test "AT-002 (#277): same-step [PASS(fp X),FAIL(fp X)] check_sameness returns continue (PASS not counted as prev)" {
  # Given: same step has PASS row and FAIL row with identical fingerprint adjacent
  # PASS 行は FAIL-only で除外、FAIL 行 1 件のみ → sameness 不成立 (#277)
  local fp
  fp=$(printf '%s' "shared-fp" | fingerprint)
  record_iteration "$JSONL" 1 "running-atdd-cycle" "PASS" "$fp"
  record_iteration "$JSONL" 2 "running-atdd-cycle" "FAIL" "$fp"
  # When: check_sameness <log> running-atdd-cycle
  run check_sameness "$JSONL" "running-atdd-cycle"
  # Then: exit code 0 (continue) -- PASS excluded by FAIL-only, only 1 FAIL row, sameness not met
  [ "$status" -eq 0 ]
}

@test "AT-004 (#277): same-step FAIL row repetition still halts (detection power maintained)" {
  # Given (a): same step FAIL rows only -- consecutive identical fingerprint x2
  local fp
  fp=$(printf '%s' "fail-repeated" | fingerprint)
  record_iteration "$JSONL" 1 "running-atdd-cycle" "FAIL" "$fp"
  record_iteration "$JSONL" 2 "running-atdd-cycle" "FAIL" "$fp"
  # When: check_sameness <log> running-atdd-cycle
  run check_sameness "$JSONL" "running-atdd-cycle"
  # Then: exit code 非ゼロ（halt）— FAIL-only 母集団でも真の FAIL 反復は検出する（#277）
  [ "$status" -ne 0 ]
  # Given (b): flatline A,A,A — 再利用のため別ファイル
  local jsonl2
  jsonl2="$TMP/log2.jsonl"
  local fpA
  fpA=$(printf '%s' "fail-A" | fingerprint)
  record_iteration "$jsonl2" 1 "running-atdd-cycle" "FAIL" "$fpA"
  record_iteration "$jsonl2" 2 "running-atdd-cycle" "FAIL" "$fpA"
  record_iteration "$jsonl2" 3 "running-atdd-cycle" "FAIL" "$fpA"
  run check_stuck "$jsonl2" 3 "running-atdd-cycle"
  [ "$status" -ne 0 ]
  # Given (c): oscillation A,B,A
  local jsonl3 fpB
  jsonl3="$TMP/log3.jsonl"
  fpA=$(printf '%s' "fail-A" | fingerprint)
  fpB=$(printf '%s' "fail-B" | fingerprint)
  record_iteration "$jsonl3" 1 "running-atdd-cycle" "FAIL" "$fpA"
  record_iteration "$jsonl3" 2 "running-atdd-cycle" "FAIL" "$fpB"
  record_iteration "$jsonl3" 3 "running-atdd-cycle" "FAIL" "$fpA"
  run check_stuck "$jsonl3" 3 "running-atdd-cycle"
  [ "$status" -ne 0 ]
}

@test "AT-005 (#277): doc-sync — lib comment, SKILL.md, iron-law, skills/README, lib/README all describe FAIL-only semantics" {
  # Given: FAIL-only フィルタの実装が完了している
  # When: 5 ドキュメントの FAIL-only 記述を grep で確認する
  # Then: いずれも「同一 step かつ verdict=FAIL の行のみを比較する」検出意味論が記載されている (#277)
  local pattern='FAIL.only|FAIL 行のみ|same-step FAIL|#277.*FAIL|FAIL.*#277|FAIL rows only'
  # lib/autopilot_convergence.sh — _fingerprints / check_sameness / check_stuck コメント
  run grep -qE "$pattern" "lib/autopilot_convergence.sh"
  [ "$status" -eq 0 ]
  # skills/autopilot/SKILL.md — rails 説明
  run grep -qE "$pattern" "skills/autopilot/SKILL.md"
  [ "$status" -eq 0 ]
  # docs/methodology/autopilot-iron-law.md — sameness/stuck 記述
  run grep -qE "$pattern" "docs/methodology/autopilot-iron-law.md"
  [ "$status" -eq 0 ]
  # skills/README.md — autopilot 行
  run grep -qE "$pattern" "skills/README.md"
  [ "$status" -eq 0 ]
  # lib/README.md — autopilot_convergence.sh 行
  run grep -qE "$pattern" "lib/README.md"
  [ "$status" -eq 0 ]
}

# --- #299: record_halt 終端レコード / timestamp 付与 ----------------------------

@test "AT-299-3: record_iteration appends a timestamp field in ISO 8601 UTC format" {
  record_iteration "$JSONL" 1 "US" "FAIL" "abc123"
  run python3 -c 'import json,sys; d=json.loads(open(sys.argv[1]).readline()); print(d["timestamp"])' "$JSONL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "AT-299-3b: record_iteration still outputs all prior fields unchanged" {
  record_iteration "$JSONL" 1 "US" "FAIL" "abc123"
  run python3 -c '
import json,sys
d=json.loads(open(sys.argv[1]).readline())
assert d["iteration"] == 1
assert d["step"] == "US"
assert d["verdict"] == "FAIL"
assert d["fingerprint"] == "abc123"
assert "timestamp" in d
print("ok")
' "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "AT-299-4: record_iteration fingerprint is the input fp arg verbatim (timestamp does not alter fp)" {
  local fp="deadbeef01234567"
  record_iteration "$JSONL" 1 "US" "FAIL" "$fp"
  run python3 -c '
import json,sys
d=json.loads(open(sys.argv[1]).readline())
got=d["fingerprint"]
exp=sys.argv[2]
assert got == exp, "expected %r, got %r" % (exp, got)
print("ok")
' "$JSONL" "$fp"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "AT-299-4b: fingerprint function does not accept a timestamp as input (structural invariant)" {
  # fingerprint() reads stdin; passing two different timestamps yields different hashes
  # because timestamp IS NOT part of a correctly structured fingerprint call.
  # Here we assert that record_iteration's fp arg is passed through unchanged
  # regardless of what date returns — by checking two consecutive calls keep distinct fps.
  local fp1="aaa111" fp2="bbb222"
  record_iteration "$JSONL" 1 "US" "FAIL" "$fp1"
  record_iteration "$JSONL" 2 "US" "FAIL" "$fp2"
  run python3 -c '
import json,sys
lines=[json.loads(l) for l in open(sys.argv[1])]
assert lines[0]["fingerprint"] == sys.argv[2]
assert lines[1]["fingerprint"] == sys.argv[3]
print("ok")
' "$JSONL" "$fp1" "$fp2"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "AT-299-1: record_halt appends a HALT record with all required fields" {
  record_iteration "$JSONL" 1 "US" "FAIL" "somefp"
  record_halt "$JSONL" "US" "MAX_ITERATIONS" '[{"priority":1,"evidence_ref":"AT-299-1#x"}]'
  local line_count
  line_count=$(wc -l < "$JSONL" | tr -d ' ')
  [ "$line_count" -eq 2 ]
  run python3 -c '
import json,sys
lines=[l for l in open(sys.argv[1]) if l.strip()]
halt=json.loads(lines[-1])
assert halt["outcome"] == "HALT", "outcome=" + halt["outcome"]
assert halt["step"] == "US", "step=" + halt["step"]
assert halt["reason"] == "MAX_ITERATIONS", "reason=" + halt["reason"]
assert isinstance(halt["findings_digest"], list), "findings_digest is not a list"
assert "timestamp" in halt, "missing timestamp"
print("ok")
' "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "AT-299-2: record_halt findings_digest is a nested JSON array (not an escaped scalar)" {
  record_halt "$JSONL" "US" "MAX_ITERATIONS" '[{"priority":1,"evidence_ref":"AT-299-2#x"}]'
  # The line must contain "findings_digest":[ (nested array) not "findings_digest":"[" (string scalar)
  run python3 -c '
import json,sys
line=open(sys.argv[1]).readline()
# structural check: must parse as object with array value, not string value
d=json.loads(line)
fd=d["findings_digest"]
assert isinstance(fd, list), "expected list, got %s" % type(fd)
assert fd[0]["priority"] == 1
assert fd[0]["evidence_ref"] == "AT-299-2#x"
print("ok")
' "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
  # also confirm raw text has the nested-array form, not escaped-string form
  run grep -F '"findings_digest":[' "$JSONL"
  [ "$status" -eq 0 ]
  run grep -F '"findings_digest":"[' "$JSONL"
  [ "$status" -ne 0 ]
}

@test "AT-299-2b: record_halt with empty findings_digest defaults to []" {
  record_halt "$JSONL" "US" "stuck" ""
  run python3 -c '
import json,sys
d=json.loads(open(sys.argv[1]).readline())
got=d["findings_digest"]
assert got == [], "expected [], got %r" % got
print("ok")
' "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "AT-299-1b: record_halt timestamp is ISO 8601 UTC" {
  record_halt "$JSONL" "US" "MAX_ITERATIONS" "[]"
  run python3 -c '
import json,re,sys
d=json.loads(open(sys.argv[1]).readline())
ts=d["timestamp"]
assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", ts), f"bad timestamp: {ts!r}"
print("ok")
' "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "AT-299-5: record_halt rejects out-of-range reason and writes no HALT line" {
  run record_halt "$JSONL" "US" "record-error" "[]"
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "AT-299-5b: record_halt rejects rails-error reason" {
  run record_halt "$JSONL" "US" "rails-error" "[]"
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "AT-299-5c: record_halt accepts all valid convergence-failure reasons (incl. #355 gate-unverifiable)" {
  # #355 (F2): gate-unverifiable は 6 番目の有効 reason として追加された
  for reason in MAX_ITERATIONS sameness-detector stuck ac-drift log-integrity gate-unverifiable; do
    local tmp; tmp="$(mktemp)"
    run record_halt "$tmp" "US" "$reason" "[]"
    [ "$status" -eq 0 ]
    rm -f "$tmp"
  done
}

@test "AT-299-1c: record_halt does not alter existing log lines" {
  record_iteration "$JSONL" 1 "US" "FAIL" "fp1"
  record_iteration "$JSONL" 2 "US" "FAIL" "fp2"
  local before; before=$(head -n 2 "$JSONL")
  record_halt "$JSONL" "US" "MAX_ITERATIONS" "[]"
  local after; after=$(head -n 2 "$JSONL")
  [ "$before" = "$after" ]
}

@test "AT-299-3c: record_iteration log stays valid JSON after timestamp addition" {
  record_iteration "$JSONL" 1 "US" "FAIL" "abc123"
  record_iteration "$JSONL" 2 "US" "PASS" "def456"
  _assert_valid_jsonl "$JSONL"
}

@test "AT-299-2c: record_halt log line is valid JSON" {
  record_halt "$JSONL" "running-atdd-cycle" "stuck" '[{"priority":0,"evidence_ref":"AC-1"}]'
  _assert_valid_jsonl "$JSONL"
}

@test "AT-006 (#277): cross-run same FAIL fingerprint recurrence halts (FAIL-only adjacency semantics pin)" {
  # 従来 continue → 新規 halt の意図された経路（#277 AT-006）。
  # FAIL-only フィルタにより PASS 行が除外されると、FAIL(A)・PASS・FAIL(A) の並びでは
  # 母集団内の FAIL 行が [fp_A, fp_A] として隣接し、「同じ失敗の繰り返し」として検出される。
  # これは承認済み PRD Outcome（#277 前提の意味論ノート）の直接帰結であり、意図された挙動。
  # Given: 同一 step に FAIL(fp A)→ PASS → FAIL(fp A) が記録されている（跨 run シナリオ）
  local fp_a fp_pass
  fp_a=$(printf '%s' "fail-A-cross-run" | fingerprint)
  fp_pass=$(printf '%s' "pass-payload" | fingerprint)
  record_iteration "$JSONL" 1 "running-atdd-cycle" "FAIL" "$fp_a"
  record_iteration "$JSONL" 2 "running-atdd-cycle" "PASS" "$fp_pass"
  record_iteration "$JSONL" 3 "running-atdd-cycle" "FAIL" "$fp_a"
  # When: check_sameness <log> running-atdd-cycle
  run check_sameness "$JSONL" "running-atdd-cycle"
  # Then: exit code 非ゼロ（halt）— FAIL-only 母集団で FAIL 行が [fp_A, fp_A] として隣接し
  # 「同じ失敗の繰り返し」として検出される（従来 continue → 新規 halt の意図経路 #277 AT-006）
  [ "$status" -ne 0 ]
}

# --- #334: record_red_evidence / check_red_evidence (deterministic red gate) ------

@test "#334: record_red_evidence appends one JSONL line with step=red and the commit sha" {
  # red 証跡が JSONL に追記されること（AL-3 green gate の対として）
  RED_JSONL="$TMP/red.jsonl"
  record_red_evidence "$RED_JSONL" "abc1234" "tests/acceptance/AT-334-A.bats"
  [ -f "$RED_JSONL" ]
  run grep -q '"step":"red"' "$RED_JSONL"
  [ "$status" -eq 0 ]
  run grep -q '"commit":"abc1234"' "$RED_JSONL"
  [ "$status" -eq 0 ]
}

@test "#334: check_red_evidence returns 0 when red evidence exists for test commit" {
  # 正順コミット（test → impl）と red 証跡があれば exit 0 を返すこと
  RED_JSONL="$TMP/red.jsonl"
  local git_repo; git_repo="$(mktemp -d)"
  git -C "$git_repo" init -q
  git -C "$git_repo" config user.email "t@t.com"
  git -C "$git_repo" config user.name "T"
  echo "t" > "$git_repo/t.bats"; git -C "$git_repo" add t.bats
  git -C "$git_repo" commit -q -m "test"
  local test_sha; test_sha="$(git -C "$git_repo" rev-parse HEAD)"
  echo "i" > "$git_repo/i.sh"; git -C "$git_repo" add i.sh
  git -C "$git_repo" commit -q -m "impl"
  local impl_sha; impl_sha="$(git -C "$git_repo" rev-parse HEAD)"
  record_red_evidence "$RED_JSONL" "$test_sha" "tests/acceptance/AT-334-A.bats"
  run check_red_evidence "$test_sha" "$impl_sha" "$RED_JSONL" "$git_repo"
  rm -rf "$git_repo"
  [ "$status" -eq 0 ]
}

@test "#334: check_red_evidence returns non-zero when no evidence exists (fail-closed)" {
  RED_JSONL="$TMP/red.jsonl"
  run check_red_evidence "test123" "impl456" "$RED_JSONL"
  [ "$status" -ne 0 ]
}

@test "#334: check_red_evidence returns non-zero when evidence is for a different commit" {
  RED_JSONL="$TMP/red.jsonl"
  record_red_evidence "$RED_JSONL" "other999" "tests/acceptance/AT-334-A.bats"
  run check_red_evidence "test123" "impl456" "$RED_JSONL"
  [ "$status" -ne 0 ]
}

@test "#334: record_red_evidence refuses empty commit sha (fail-closed, same as record_iteration)" {
  RED_JSONL="$TMP/red.jsonl"
  run record_red_evidence "$RED_JSONL" "" "tests/acceptance/AT-334-A.bats"
  [ "$status" -ne 0 ]
  [ ! -s "$RED_JSONL" ]
}

@test "#334: record_red_evidence refuses commit sha with newline (would split JSONL)" {
  RED_JSONL="$TMP/red.jsonl"
  run record_red_evidence "$RED_JSONL" "$(printf 'abc\ndef')" "tests/acceptance/AT-334-A.bats"
  [ "$status" -ne 0 ]
  [ ! -s "$RED_JSONL" ]
}

@test "#334: record_red_evidence refuses commit sha with double-quote (would forge JSON)" {
  RED_JSONL="$TMP/red.jsonl"
  run record_red_evidence "$RED_JSONL" 'abc"def' "tests/acceptance/AT-334-A.bats"
  [ "$status" -ne 0 ]
  [ ! -s "$RED_JSONL" ]
}

@test "#334: check_red_evidence requires non-empty test-commit sha" {
  RED_JSONL="$TMP/red.jsonl"
  run check_red_evidence "" "impl456" "$RED_JSONL"
  [ "$status" -ne 0 ]
}

@test "#334: check_red_evidence requires non-empty impl-commit sha" {
  RED_JSONL="$TMP/red.jsonl"
  run check_red_evidence "test123" "" "$RED_JSONL"
  [ "$status" -ne 0 ]
}

@test "#334: check_red_evidence rejects impl-commit sha with invalid charset (symmetric with test_sha)" {
  # impl_sha のバリデーションが test_sha と対称であること（将来の JSON 埋め込み拡張時の安全性担保）
  # チェックが red_jsonl の存在確認より先に走ることで、ファイルなしの失敗と区別できる
  RED_JSONL="$TMP/red.jsonl"
  record_red_evidence "$RED_JSONL" "test123" "tests/acceptance/AT-334-A.bats"
  run check_red_evidence "test123" "impl/sha;bad" "$RED_JSONL"
  [ "$status" -eq 2 ]  # charset 拒否は return 2（file-not-found の return 1 と区別）
}

# --- #355 (AT-355-F8): record_red_evidence impl_sha 拡張 ----------------------
# F8: record_red_evidence が test SHA と impl baseline SHA の両方を red.jsonl へ記録する。
# check_red_evidence が git log 考古学ではなく red.jsonl の記録済み impl_sha を引数で受ける。

@test "AT-355-F8-1: record_red_evidence appends both commit (test sha) and impl_sha to red.jsonl" {
  # Given: 一時 red.jsonl
  RED_JSONL="$TMP/red-f8.jsonl"
  # When: record_red_evidence を test SHA, impl baseline SHA, AT ファイル名で呼ぶ
  record_red_evidence "$RED_JSONL" "testsha123" "tests/acceptance/AT-355-F8.bats" "implsha456"
  # Then: commit（test SHA）と impl_sha の両フィールドが JSONL 行に存在し、JSON として整合している
  [ -f "$RED_JSONL" ]
  run grep -q '"commit":"testsha123"' "$RED_JSONL"
  [ "$status" -eq 0 ]
  run grep -q '"impl_sha":"implsha456"' "$RED_JSONL"
  [ "$status" -eq 0 ]
  # JSON として整形されていること（python3 で parse 可能）
  run python3 -c 'import json,sys; json.loads(open(sys.argv[1]).readline()); print("ok")' "$RED_JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "AT-355-F8-1b: record_red_evidence without impl_sha arg remains backward-compatible" {
  # impl_sha は省略可能（既存コードとの後方互換）
  RED_JSONL="$TMP/red-f8b.jsonl"
  record_red_evidence "$RED_JSONL" "testsha123" "tests/acceptance/AT-355-F8.bats"
  [ -f "$RED_JSONL" ]
  run grep -q '"commit":"testsha123"' "$RED_JSONL"
  [ "$status" -eq 0 ]
}

@test "AT-355-F8-2: check_red_evidence accepts test_sha and impl_sha from arguments (not git log)" {
  # Given: red.jsonl に test SHA + impl_sha の記録がある一時 git リポジトリ
  RED_JSONL="$TMP/red-f8-2.jsonl"
  local git_repo; git_repo="$(mktemp -d)"
  git -C "$git_repo" init -q
  git -C "$git_repo" config user.email "t@t.com"
  git -C "$git_repo" config user.name "T"
  echo "t" > "$git_repo/t.bats"; git -C "$git_repo" add t.bats
  git -C "$git_repo" commit -q -m "test"
  local test_sha; test_sha="$(git -C "$git_repo" rev-parse HEAD)"
  echo "i" > "$git_repo/i.sh"; git -C "$git_repo" add i.sh
  git -C "$git_repo" commit -q -m "impl"
  local impl_sha; impl_sha="$(git -C "$git_repo" rev-parse HEAD)"
  # record_red_evidence に impl_sha も渡す
  record_red_evidence "$RED_JSONL" "$test_sha" "tests/acceptance/AT-355-F8.bats" "$impl_sha"
  # When: check_red_evidence を引数で直接渡す（git log 考古学に依存しない）
  run check_red_evidence "$test_sha" "$impl_sha" "$RED_JSONL" "$git_repo"
  rm -rf "$git_repo"
  # Then: exit 0（redObserved=true）
  [ "$status" -eq 0 ]
}

@test "AT-355-F8-3: check_red_evidence returns non-zero when no evidence for test sha (fail-closed)" {
  # Given: red.jsonl に該当 test SHA の記録がない
  RED_JSONL="$TMP/red-f8-3.jsonl"
  # Then: 非 0（fail-closed）
  run check_red_evidence "norecord999" "implxyz" "$RED_JSONL"
  [ "$status" -ne 0 ]
}

# --- #355 (AT-355-F2): record_halt gate-unverifiable 追加 ----------------------
# F2: record_halt が gate-unverifiable reason を受理する。

@test "AT-355-F2-1: record_halt accepts gate-unverifiable reason" {
  # Given: 一時 JSONL ログ
  # When: record_halt を reason gate-unverifiable で呼ぶ
  run record_halt "$JSONL" "running-atdd-cycle" "gate-unverifiable" "[]"
  # Then: HALT 行が追記され exit 0
  [ "$status" -eq 0 ]
  run grep -q '"outcome":"HALT"' "$JSONL"
  [ "$status" -eq 0 ]
  run grep -q '"reason":"gate-unverifiable"' "$JSONL"
  [ "$status" -eq 0 ]
}

@test "AT-355-F2-2: record_halt still rejects unknown reasons (enum guard maintained)" {
  # Given: enum 外の reason
  run record_halt "$JSONL" "US" "unknown-reason-xyz" "[]"
  # Then: 非 0（enum 検証の fail-safe を維持）
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

@test "AT-355-F2-1b: record_halt gate-unverifiable HALT line is valid JSON" {
  record_halt "$JSONL" "running-atdd-cycle" "gate-unverifiable" "[]"
  run python3 -c 'import json,sys; d=json.loads(open(sys.argv[1]).readline()); assert d["outcome"]=="HALT"; assert d["reason"]=="gate-unverifiable"; print("ok")' "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}
