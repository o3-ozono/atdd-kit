#!/usr/bin/env bats
# @covers: skills/extracting-user-stories/SKILL.md
# Skill E2E Test for the extracting-user-stories skill (#222 / #189).
# Invokes real `claude -p` (single-turn) and verifies the LLM correctly
# recovers the behavior aspects encoded in SKILL.md.
#
# 1 file = 1 skill, 1 @test = 1 User Story (Connextra form).
# User Stories source: docs/issues/189-extracting-user-stories-skill/user-stories.md
#
# Prompts ask the LLM to respond in English so the grep-based assertions stay
# stable. This is unrelated to the skill's output language policy (Japanese
# fixed for the generated user-stories.md, see SKILL.md "Output language").

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/extracting-user-stories/SKILL.md"
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

@test "F1: I want to extract User Stories from a PRD into docs/issues/<NNN>/user-stories.md, so that AT input is stable" {
  prompt="The following is the atdd-kit extracting-user-stories skill definition. \
State the exact input file path and the exact output file path this skill operates on. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -q "prd.md"
  echo "$out" | grep -q "user-stories.md"
}

@test "F2: I want the skill to present Story candidates in one batch, so that review effort stays low" {
  prompt="The following is the atdd-kit extracting-user-stories skill definition. \
Describe how the skill presents Story candidates to the user — one at a time or all at once? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "one (message|batch)|all at once|batch|together"
}

# C1 (SKILL.md ≤ 200 lines) is a structural invariant; verified mechanically by
# tests/test_extracting_user_stories_skill.bats (Unit Test) via `wc -l`. No
# Skill E2E case is needed — the LLM would only restate what `wc -l` already
# proves.

@test "C2: I want the generated user-stories.md body to be Japanese only, so that output language is fixed" {
  prompt="The following is the atdd-kit extracting-user-stories skill definition. \
What is the output language policy for the generated user-stories.md file? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qi "japanese"
}

@test "C3: I want no 'As a [persona]' patterns in output, so that the v1.0 persona-less judgment is mechanically enforced" {
  prompt="The following is the atdd-kit extracting-user-stories skill definition. \
Does this skill include a persona field (such as 'As a user' or 'As a developer') in its output? Answer yes or no and quote the relevant line. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  # Must explicitly mention persona AND express absence/negation, so a bare
  # "No." cannot pass the gate.
  echo "$out" | grep -qi "persona"
  echo "$out" | grep -qiE "\bno\b|does not|does not include|persona-less|without persona|no persona|absent|not included"
}
