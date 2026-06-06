#!/usr/bin/env bats
# @covers: skills/merging-and-deploying/SKILL.md
# Skill E2E Test for the merging-and-deploying skill (#193 / #179 Step B6).
# Invokes real `claude -p` (single-turn) and verifies the LLM correctly
# recovers the behavior aspects encoded in SKILL.md.
#
# 1 file = 1 skill, 1 @test = 1 User Story (Connextra form).
# User Stories derived from #193 AC (Step B6).
#
# Prompts ask the LLM to respond in English so the grep-based assertions stay
# stable. This is unrelated to the skill's output language policy.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/merging-and-deploying/SKILL.md"
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

@test "F1: I want a merge then deploy then regression flow, so that shipping follows an ordered, repeatable sequence" {
  prompt="The following is the atdd-kit merging-and-deploying skill definition. \
List, in order, the phases of the flow it runs. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qi "merge"
  echo "$out" | grep -qi "deploy"
  echo "$out" | grep -qi "regression"
}

@test "F2: I want the Acceptance Tests re-run after deploy, so that production is verified against the same green tests" {
  prompt="The following is the atdd-kit merging-and-deploying skill definition. \
After deploying, which tests does it re-run and from which directory? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "acceptance test"
  echo "$out" | grep -qi "tests/acceptance"
  echo "$out" | grep -qiE "re-?run|re-?execut"
}

@test "F3: I want a passing review required before merge, so that only reviewed deliverables ship" {
  prompt="The following is the atdd-kit merging-and-deploying skill definition. \
What precondition must hold before it merges the PR? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "review|reviewing-deliverables|PASS"
}
