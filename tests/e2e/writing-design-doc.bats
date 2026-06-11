#!/usr/bin/env bats
# @covers: skills/writing-design-doc/SKILL.md
# Skill E2E Test for the writing-design-doc skill (#195 / #179 Step B8).
# Invokes real `claude -p` (single-turn) and verifies the LLM correctly
# recovers the behavior aspects encoded in SKILL.md.
#
# 1 file = 1 skill, 1 @test = 1 User Story (Connextra form).
# User Stories derived from #195 AC (Step B8).
#
# Prompts ask the LLM to respond in English so the grep-based assertions stay
# stable. This is unrelated to the skill's output language policy.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/writing-design-doc/SKILL.md"
TIMEOUT_SECS="${SKILL_E2E_TIMEOUT_SECS:-120}"
E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"

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
      --model "${E2E_MODEL}" \
      --max-turns 1 \
      --permission-mode bypassPermissions \
      2>/dev/null
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$TIMEOUT_SECS" "$CLAUDE_BIN" -p "$prompt" \
      --model "${E2E_MODEL}" \
      --max-turns 1 \
      --permission-mode bypassPermissions \
      2>/dev/null
  else
    "$CLAUDE_BIN" -p "$prompt" \
      --model "${E2E_MODEL}" \
      --max-turns 1 \
      --permission-mode bypassPermissions \
      2>/dev/null
  fi
}

@test "F1: I want a doc only when trade-offs exist, so that obvious designs skip the overhead" {
  prompt="The following is the atdd-kit writing-design-doc skill definition. \
When should it produce a design doc, and when should it skip? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "trade-?off|alternative"
  echo "$out" | grep -qiE "skip|obvious"
}

@test "F2: I want the Ubl 2020 sections, so that the decision is captured in a known structure" {
  prompt="The following is the atdd-kit writing-design-doc skill definition. \
What sections does the design document contain? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "trade-?off"
  echo "$out" | grep -qiE "alternative"
  echo "$out" | grep -qiE "non-goal|goal"
}

@test "F3: I want the doc at a known path, so that it lives with the Issue artifacts" {
  prompt="The following is the atdd-kit writing-design-doc skill definition. \
Where is the design document written? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "docs/issues|design-doc\.md"
}
