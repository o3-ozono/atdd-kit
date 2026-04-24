#!/usr/bin/env bats
# @covers: lib/transition_detector.sh
# Issue #162: primitive unit tests for the same-turn vs cross-turn detector.

DETECTOR="lib/transition_detector.sh"
FIXTURES="tests/fixtures/autopilot-phase1"

# ------------------------------------------------------------------
# Canonical Source self-consistency (Plan Review C1 / Finding)
# ------------------------------------------------------------------

@test "canonical: skill-status spec lists spawn_ac_review_agents" {
  grep -q 'spawn_ac_review_agents' docs/guides/skill-status-spec.md
}

# ------------------------------------------------------------------
# Usage / argument handling
# ------------------------------------------------------------------

@test "usage: exits 1 when no argument given" {
  run bash "$DETECTOR"
  [ "$status" -eq 1 ]
}

@test "usage: exits 1 when transcript missing" {
  run bash "$DETECTOR" /nonexistent/path.jsonl
  [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# same-turn fixture
# ------------------------------------------------------------------

@test "same-turn: exits 0" {
  run bash "$DETECTOR" "$FIXTURES/same-turn.jsonl"
  [ "$status" -eq 0 ]
}

@test "same-turn: same_turn_spawn == true" {
  run bash "$DETECTOR" "$FIXTURES/same-turn.jsonl"
  echo "$output" | jq -e '.same_turn_spawn == true'
}

@test "same-turn: next assistant contains 2 Agent tool_uses" {
  run bash "$DETECTOR" "$FIXTURES/same-turn.jsonl"
  local count
  count=$(echo "$output" | jq '[.next_assistant_tool_uses[] | select(. == "Agent")] | length')
  [ "$count" -eq 2 ]
}

@test "same-turn: intervening_user_msgs == 0" {
  run bash "$DETECTOR" "$FIXTURES/same-turn.jsonl"
  echo "$output" | jq -e '.intervening_user_msgs == 0'
}

@test "same-turn: next_assistant_msg_index is exactly skill_result_user_msg_index + 1" {
  run bash "$DETECTOR" "$FIXTURES/same-turn.jsonl"
  echo "$output" | jq -e '.next_assistant_msg_index - .skill_result_user_msg_index == 1'
}

@test "same-turn: skill_tool_use_id is non-empty" {
  run bash "$DETECTOR" "$FIXTURES/same-turn.jsonl"
  echo "$output" | jq -e '.skill_tool_use_id | type == "string" and length > 0'
}

# ------------------------------------------------------------------
# cross-turn fixture
# ------------------------------------------------------------------

@test "cross-turn: exits 0" {
  run bash "$DETECTOR" "$FIXTURES/cross-turn.jsonl"
  [ "$status" -eq 0 ]
}

@test "cross-turn: same_turn_spawn == false" {
  run bash "$DETECTOR" "$FIXTURES/cross-turn.jsonl"
  echo "$output" | jq -e '.same_turn_spawn == false'
}

@test "cross-turn: next_assistant_tool_uses contains no Agent" {
  run bash "$DETECTOR" "$FIXTURES/cross-turn.jsonl"
  local count
  count=$(echo "$output" | jq '[.next_assistant_tool_uses[] | select(. == "Agent")] | length')
  [ "$count" -eq 0 ]
}

# ------------------------------------------------------------------
# no-skill-found fixture
# ------------------------------------------------------------------

@test "no-skill: exits 2" {
  run bash "$DETECTOR" "$FIXTURES/no-skill.jsonl"
  [ "$status" -eq 2 ]
}

@test "no-skill: error field is skill_tool_use_not_found" {
  run bash "$DETECTOR" "$FIXTURES/no-skill.jsonl"
  echo "$output" | jq -e '.error == "skill_tool_use_not_found"'
}

@test "no-skill: same_turn_spawn == false" {
  run bash "$DETECTOR" "$FIXTURES/no-skill.jsonl"
  echo "$output" | jq -e '.same_turn_spawn == false'
}

# ------------------------------------------------------------------
# --skill-name override
# ------------------------------------------------------------------

@test "override: non-matching --skill-name returns no-skill error" {
  run bash "$DETECTOR" --skill-name "atdd-kit:plan" "$FIXTURES/same-turn.jsonl"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.error == "skill_tool_use_not_found"'
}
