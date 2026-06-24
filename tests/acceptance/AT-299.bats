#!/usr/bin/env bats
# @covers: lib/autopilot_convergence.sh (record_halt / timestamp)
# @covers: skills/autopilot/SKILL.md (convergence-failure halt JSONL record wiring)
# Acceptance Tests for Issue #299: append a terminating HALT record to the JSONL audit log

setup() {
  LIB="lib/autopilot_convergence.sh"
  source "$LIB"
  TMP="$(mktemp -d)"
  JSONL="$TMP/autopilot-log.jsonl"
  SKILL_FILE="skills/autopilot/SKILL.md"
}

teardown() {
  rm -rf "$TMP"
}

# AT-299-1: record_halt appends a terminating HALT record on convergence-failure halt
@test "AT-299-1: record_halt appends a HALT record to the JSONL" {
  record_iteration "$JSONL" 1 "US" "FAIL" "somefp"
  record_halt "$JSONL" "US" "MAX_ITERATIONS" '[{"priority":1,"evidence_ref":"AT-299-1#x"}]'
  # HALT record is appended as a new line, existing lines unchanged
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
  # first line is still the iteration record
  run python3 -c '
import json,sys
lines=[l for l in open(sys.argv[1]) if l.strip()]
it=json.loads(lines[0])
assert "iteration" in it, "first line is not an iteration record"
print("ok")
' "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

# AT-299-2: findings_digest is a nested JSON array (not an escaped string scalar)
@test "AT-299-2: findings_digest embeds as a nested JSON array, not an escaped string scalar" {
  record_halt "$JSONL" "US" "MAX_ITERATIONS" '[{"priority":1,"evidence_ref":"AT-299-2#x"}]'
  # raw text form: "findings_digest":[ not "findings_digest":"[
  run grep -F '"findings_digest":[' "$JSONL"
  [ "$status" -eq 0 ]
  run grep -F '"findings_digest":"[' "$JSONL"
  [ "$status" -ne 0 ]
  # JSON parser sees a list with accessible priority and evidence_ref fields
  run python3 -c '
import json,sys
d=json.loads(open(sys.argv[1]).readline())
fd=d["findings_digest"]
assert isinstance(fd, list), "expected list, got %s" % type(fd)
assert fd[0]["priority"] == 1
assert fd[0]["evidence_ref"] == "AT-299-2#x"
print("ok")
' "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

# AT-299-3: each iteration row carries a timestamp
@test "AT-299-3: record_iteration appends a timestamp field in ISO 8601 UTC format" {
  record_iteration "$JSONL" 1 "US" "FAIL" "abc123"
  run python3 -c '
import json,re,sys
d=json.loads(open(sys.argv[1]).readline())
ts=d.get("timestamp","")
assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", ts), "bad timestamp: %r" % ts
assert d["iteration"] == 1
assert d["step"] == "US"
assert d["verdict"] == "FAIL"
assert d["fingerprint"] == "abc123"
print("ok")
' "$JSONL"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

# AT-299-4: timestamp does not alter fingerprint — determinism is preserved
@test "AT-299-4: record_iteration passes fp arg verbatim without modification (timestamp not in fp path)" {
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

# AT-299-5: record_halt rejects out-of-range reason (convergence-failure enum only)
@test "AT-299-5: record_halt rejects record-error reason and writes no HALT line" {
  run record_halt "$JSONL" "US" "record-error" "[]"
  [ "$status" -ne 0 ]
  [ ! -s "$JSONL" ]
}

# AT-299-5b: SKILL.md wires record_halt only to convergence-failure halt path
@test "AT-299-5b: SKILL.md wires record_halt only to convergence-failure halt, not to error return paths" {
  grep -qF 'record_halt "<resolved-log-path>"' "$SKILL_FILE"
  ! grep -E "reason: 'record-error'" "$SKILL_FILE" | grep -q 'record_halt'
  ! grep -E "reason: 'rails-error'" "$SKILL_FILE" | grep -q 'record_halt'
  ! grep -E "reason: 'freeze-error'" "$SKILL_FILE" | grep -q 'record_halt'
  ! grep -E "reason: 'anchor-pin-failed'" "$SKILL_FILE" | grep -q 'record_halt'
}

# AT-299-6: halt record is committed with log-only stage+commit (same as #288)
@test "AT-299-6: halt record agent commits ONLY the audit log (log-only stage+commit)" {
  grep -qF 'audit-halt:' "$SKILL_FILE"
  grep -qE 'git add.*resolved-log-path.*&&.*git commit.*halt record' "$SKILL_FILE"
}

# AT-299-7: return value COMPLETED_WITH_DEBT coexists with the HALT record
@test "AT-299-7: return COMPLETED_WITH_DEBT is still present after halt record insertion" {
  # #355/#359 で LLM レビュー削除に伴い verdict フィールドが除去された（旧: ..., reason: halt, verdict }）
  grep -qF "return { status: 'COMPLETED_WITH_DEBT', step, reason: halt }" "$SKILL_FILE"
  local halt_line ret_line
  halt_line=$(grep -n 'record_halt "<resolved-log-path>"' "$SKILL_FILE" | head -1 | cut -d: -f1)
  ret_line=$(grep -n "return { status: 'COMPLETED_WITH_DEBT', step, reason: halt" "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$halt_line" ] && [ -n "$ret_line" ]
  [ "$halt_line" -lt "$ret_line" ]
}

# AT-299-8: HALT append does not break log-integrity counter (OQ3 resolution)
@test "AT-299-8: HALT record append is after all rails checks; recorded not incremented; no integrity re-run" {
  # recorded++ appears exactly once (only the normal audit increment)
  local count
  count=$(grep -c 'recorded++' "$SKILL_FILE")
  [ "$count" -eq 1 ]
  # record_halt is placed after the rails agent call in line order
  local rails_line halt_block_line
  rails_line=$(grep -n "label: \`rails:" "$SKILL_FILE" | head -1 | cut -d: -f1)
  halt_block_line=$(grep -n 'record_halt "<resolved-log-path>"' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$rails_line" ] && [ -n "$halt_block_line" ]
  [ "$rails_line" -lt "$halt_block_line" ]
  # invariant comment exists in SKILL.md
  grep -qiE 'recorded.*NOT.*increment|NOT.*increment.*recorded' "$SKILL_FILE"
}
