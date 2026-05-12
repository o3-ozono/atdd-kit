#!/usr/bin/env bats
# @covers: skills/defining-requirements/SKILL.md
# Skill E2E Test for the defining-requirements skill (#222 / #188).
# Invokes real `claude -p` (single-turn) and verifies the LLM correctly
# recovers the behavior aspects encoded in SKILL.md.
#
# 1 file = 1 skill, 1 @test = 1 User Story (Connextra form).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/defining-requirements/SKILL.md"
TIMEOUT_SECS="${SKILL_E2E_TIMEOUT_SECS:-120}"

setup() {
  if [ ! -f "$SKILL_FILE" ]; then
    skip "SKILL.md not found: $SKILL_FILE"
  fi
  if ! command -v claude >/dev/null 2>&1 && [ -z "${SKILL_TEST_CLAUDE_BIN:-}" ]; then
    skip "claude binary not found in PATH and SKILL_TEST_CLAUDE_BIN not set"
  fi
  CLAUDE_BIN="${SKILL_TEST_CLAUDE_BIN:-claude}"
  SKILL_CONTENT=$(cat "$SKILL_FILE")
}

_run_claude() {
  local prompt="$1"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SECS" "$CLAUDE_BIN" -p "$prompt" \
      --max-turns 1 \
      --permission-mode bypassPermissions \
      2>/dev/null
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$TIMEOUT_SECS" "$CLAUDE_BIN" -p "$prompt" \
      --max-turns 1 \
      --permission-mode bypassPermissions \
      2>/dev/null
  else
    "$CLAUDE_BIN" -p "$prompt" \
      --max-turns 1 \
      --permission-mode bypassPermissions \
      2>/dev/null
  fi
}

@test "I want to read the SKILL.md and recover the 6 PRD sections, so that section coverage is verified" {
  prompt="The following is the atdd-kit defining-requirements skill definition. \
List the six PRD sections defined in the Flow, in order. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qi "Problem"
  echo "$out" | grep -qi "Why now"
  echo "$out" | grep -qi "Outcome"
  echo "$out" | grep -qiE "(^|[^a-zA-Z])What([^a-zA-Z]|$)"
  echo "$out" | grep -qi "Non-Goals"
  echo "$out" | grep -qi "Open Questions"
}

@test "I want to see upstream session-start cited before downstream extracting-user-stories, so that chain order is preserved" {
  prompt="The following is the atdd-kit defining-requirements skill definition. \
Name the upstream skill first, then name the downstream skill. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  up_line=$(echo "$out" | grep -n "session-start" | head -1 | cut -d: -f1)
  down_line=$(echo "$out" | grep -n "extracting-user-stories" | head -1 | cut -d: -f1)
  [ -n "$up_line" ]
  [ -n "$down_line" ]
  [ "$up_line" -lt "$down_line" ]
}

@test "I want to verify the skill writes to docs/issues/<NNN>/prd.md, so that output path is correct" {
  prompt="The following is the atdd-kit defining-requirements skill definition. \
State the exact output file path that this skill writes. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -q "docs/issues"
  echo "$out" | grep -q "prd.md"
}
