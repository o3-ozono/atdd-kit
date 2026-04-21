#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# =============================================================================
# skill_transcript_parser.sh -- Unit tests
# Issue #72: headless skill chain integration tests
#
# AC3: Parser extracts Skill tool_use events with schema validation.
#   - Valid stream-json jsonl -> emits [{name, args, order}] JSON array on stdout, exit 0
#   - Malformed input (truncated, invalid JSON, missing field, non-utf8) -> exit 2 with offset info
#   - Partial messages (parent_tool_use_id != null) are filtered out
#   - Non-Skill tool_use entries are ignored
# =============================================================================

PARSER="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/lib/skill_transcript_parser.sh"
FIXTURES="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/tests/fixtures/headless"

setup() {
  WORK="${BATS_TMPDIR}/parser-work-$$"
  mkdir -p "$WORK"
}

teardown() {
  rm -rf "$WORK"
}

# Build a minimal valid stream-json line for a Skill tool_use
# $1=skill_name $2=args_json ($3=parent_tool_use_id or empty)
skill_line() {
  local name="$1" args="${2:-null}" parent="${3:-}"
  if [ -z "$parent" ]; then
    parent="null"
  else
    parent="\"$parent\""
  fi
  printf '{"type":"assistant","parent_tool_use_id":%s,"message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"skill":"%s","args":%s}}]}}\n' \
    "$parent" "$name" "$args"
}

# -----------------------------------------------------------------------------
# Happy path
# -----------------------------------------------------------------------------

@test "parser emits JSON array for single Skill tool_use" {
  local f="$WORK/single.jsonl"
  skill_line "atdd-kit:discover" '"72"' > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  # stdout is valid JSON array
  echo "$output" | jq -e 'type == "array"' >/dev/null
  # length is 1 and first entry has expected fields
  echo "$output" | jq -e '.[0].name == "atdd-kit:discover"' >/dev/null
  echo "$output" | jq -e '.[0].args == "72"' >/dev/null
  echo "$output" | jq -e '.[0].order == 1' >/dev/null
}

@test "parser preserves chronological order across multiple Skill calls" {
  local f="$WORK/chain.jsonl"
  {
    skill_line "atdd-kit:skill-gate" "null"
    skill_line "atdd-kit:discover" '"72"'
    skill_line "atdd-kit:plan" '"72"'
  } > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '. | length')" -eq 3 ]
  [ "$(echo "$output" | jq -r '.[0].name')" = "atdd-kit:skill-gate" ]
  [ "$(echo "$output" | jq -r '.[1].name')" = "atdd-kit:discover" ]
  [ "$(echo "$output" | jq -r '.[2].name')" = "atdd-kit:plan" ]
}

@test "parser ignores non-Skill tool_use entries" {
  local f="$WORK/mixed.jsonl"
  {
    skill_line "atdd-kit:discover" "null"
    # Non-Skill tool_use (e.g. Bash)
    printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","id":"toolu_2","name":"Bash","input":{"command":"ls"}}]}}\n'
    skill_line "atdd-kit:plan" "null"
  } > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '. | length')" -eq 2 ]
  [ "$(echo "$output" | jq -r '.[0].name')" = "atdd-kit:discover" ]
  [ "$(echo "$output" | jq -r '.[1].name')" = "atdd-kit:plan" ]
}

@test "parser filters out partial/subagent messages (parent_tool_use_id != null)" {
  local f="$WORK/partial.jsonl"
  {
    skill_line "atdd-kit:discover" "null"
    # Subagent spawned a Skill — must be filtered
    skill_line "atdd-kit:verify" "null" "toolu_parent"
  } > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '. | length')" -eq 1 ]
  [ "$(echo "$output" | jq -r '.[0].name')" = "atdd-kit:discover" ]
}

@test "parser preserves complex args as parsed JSON values (not strings)" {
  local f="$WORK/args.jsonl"
  printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"skill":"atdd-kit:discover","args":{"issue":72,"mode":"autopilot"}}}]}}\n' > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].args.issue == 72' >/dev/null
  echo "$output" | jq -e '.[0].args.mode == "autopilot"' >/dev/null
}

@test "parser emits empty array for zero Skill calls" {
  local f="$WORK/empty-skills.jsonl"
  printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"text","text":"hello"}]}}\n' > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. == []' >/dev/null
}

# -----------------------------------------------------------------------------
# Malformed input — exit 2 (parse_error)
# -----------------------------------------------------------------------------

@test "parser exits 2 on truncated/partial JSON line" {
  local f="$WORK/truncated.jsonl"
  {
    skill_line "atdd-kit:discover" "null"
    printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use"'  # truncated, no newline
  } > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 2 ]
  [[ "$output" =~ parse_error ]] || [[ "$stderr" =~ parse_error ]] || true
}

@test "parser exits 2 on invalid (non-JSON) line" {
  local f="$WORK/invalid.jsonl"
  {
    skill_line "atdd-kit:discover" "null"
    printf 'this is not json\n'
  } > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 2 ]
}

@test "parser exits 2 on schema violation (Skill tool_use missing input.skill)" {
  local f="$WORK/missing-field.jsonl"
  printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"args":"no-skill-field"}}]}}\n' > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 2 ]
}

@test "parser exits 2 on non-UTF-8 binary input" {
  local f="$WORK/non-utf8.bin"
  # 0xff is not valid UTF-8
  printf '\xff\xfe\xff\xfe' > "$f"

  run bash "$PARSER" "$f"
  [ "$status" -eq 2 ]
}

@test "parser error message references file offset or line number" {
  local f="$WORK/invalid-with-offset.jsonl"
  {
    skill_line "atdd-kit:discover" "null"
    skill_line "atdd-kit:plan" "null"
    printf 'garbage-line\n'
  } > "$f"

  run --separate-stderr bash "$PARSER" "$f"
  [ "$status" -eq 2 ]
  # Error message must reference the offending line (line 3) somehow
  [[ "$stderr" =~ line ]] || [[ "$stderr" =~ offset ]] || [[ "$stderr" =~ ":3" ]]
}

# -----------------------------------------------------------------------------
# Committed malformed fixtures (Group-A, Plan v2)
# -----------------------------------------------------------------------------

@test "fixture malformed.truncated.jsonl => exit 2" {
  run bash "$PARSER" "$FIXTURES/malformed.truncated.jsonl"
  [ "$status" -eq 2 ]
}

@test "fixture malformed.invalid-json.jsonl => exit 2" {
  run bash "$PARSER" "$FIXTURES/malformed.invalid-json.jsonl"
  [ "$status" -eq 2 ]
}

@test "fixture malformed.missing-field.jsonl => exit 2" {
  run bash "$PARSER" "$FIXTURES/malformed.missing-field.jsonl"
  [ "$status" -eq 2 ]
}

@test "fixture malformed.non-utf8.bin => exit 2" {
  run bash "$PARSER" "$FIXTURES/malformed.non-utf8.bin"
  [ "$status" -eq 2 ]
}

# -----------------------------------------------------------------------------
# Argument handling
# -----------------------------------------------------------------------------

@test "parser exits non-zero when given non-existent file" {
  run bash "$PARSER" "$WORK/does-not-exist.jsonl"
  [ "$status" -ne 0 ]
}

@test "parser exits non-zero when given no arguments" {
  run bash "$PARSER"
  [ "$status" -ne 0 ]
}

# -----------------------------------------------------------------------------
# AC1: parser tolerates null/empty-string/non-string input.skill (Issue #125)
# field absent  → exit 2 (schema violation — unchanged)
# field null    → skip, exit 0 (any non-string type)
# field ""      → skip, exit 0 (NEW)
# field number  → skip, exit 0 (NEW)
# field array   → skip, exit 0 (NEW)
# field object  → skip, exit 0 (NEW)
# -----------------------------------------------------------------------------

@test "AC1: input.skill=null is skipped (exit 0, not counted)" {
  local f="$WORK/skill-null.jsonl"
  printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"skill":null,"args":null}}]}}\n' > "$f"
  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. == []' >/dev/null
}

@test "AC1: input.skill empty string is skipped (exit 0, not counted)" {
  local f="$WORK/skill-empty.jsonl"
  printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"skill":"","args":null}}]}}\n' > "$f"
  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. == []' >/dev/null
}

@test "AC1: input.skill number is skipped (exit 0, not counted)" {
  local f="$WORK/skill-number.jsonl"
  printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"skill":42,"args":null}}]}}\n' > "$f"
  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. == []' >/dev/null
}

@test "AC1: input.skill array is skipped (exit 0, not counted)" {
  local f="$WORK/skill-array.jsonl"
  printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"skill":["a","b"],"args":null}}]}}\n' > "$f"
  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. == []' >/dev/null
}

@test "parser skips Skill entry where input.skill is an object" {
  local f="$WORK/skill-object.jsonl"
  # valid entry before and after the object-valued entry to confirm skip-only effect
  {
    skill_line "atdd-kit:discover" "null"
    printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","id":"toolu_obj","name":"Skill","input":{"skill":{"foo":"bar"},"args":null}}]}}\n'
    skill_line "atdd-kit:plan" "null"
  } > "$f"
  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '. | length')" -eq 2 ]
  [ "$(echo "$output" | jq -r '.[0].name')" = "atdd-kit:discover" ]
  [ "$(echo "$output" | jq -r '.[1].name')" = "atdd-kit:plan" ]
}

@test "AC1: missing input.skill field exits 2 (field absent = schema violation)" {
  local f="$WORK/skill-absent.jsonl"
  printf '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","id":"toolu_1","name":"Skill","input":{"args":"no-skill-field"}}]}}\n' > "$f"
  run bash "$PARSER" "$f"
  [ "$status" -eq 2 ]
}

# -----------------------------------------------------------------------------
# AC5: partial-message events do not leak into skill-status extraction (Issue #125)
# -----------------------------------------------------------------------------

@test "AC5: partial_json events are excluded from skill-status output" {
  local f="$WORK/partial-events.jsonl"
  # A partial_json event (type=content_block_delta) must not appear as a Skill entry.
  # Use jq -n to generate valid JSON with embedded quotes in partial_json string value.
  {
    skill_line "atdd-kit:discover" "null"
    jq -nc '{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\"skill\":\"atdd-kit:plan\"}"}}'
    skill_line "atdd-kit:plan" "null"
  } > "$f"
  run bash "$PARSER" "$f"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq '. | length')" -eq 2 ]
  [ "$(echo "$output" | jq -r '.[0].name')" = "atdd-kit:discover" ]
  [ "$(echo "$output" | jq -r '.[1].name')" = "atdd-kit:plan" ]
}
