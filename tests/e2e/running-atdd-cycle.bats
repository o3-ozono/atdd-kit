#!/usr/bin/env bats
# @covers: skills/running-atdd-cycle/SKILL.md
# Skill E2E Test for the running-atdd-cycle skill (#191 / #179 Step B4).
# Invokes real `claude -p` (single-turn) and verifies the LLM correctly
# recovers the behavior aspects encoded in SKILL.md.
#
# 1 file = 1 skill, 1 @test = 1 User Story (Connextra form).
# User Stories derived from #191 AC (Step B4) — the C1-C5 ATDD interpretation.
#
# Prompts ask the LLM to respond in English so the grep-based assertions stay
# stable. This is unrelated to the skill's output language policy.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/running-atdd-cycle/SKILL.md"
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

@test "F1: I want plan + draft Acceptance Tests turned into executable AT files, so that the ATDD outer loop runs against real tests" {
  prompt="The following is the atdd-kit running-atdd-cycle skill definition. \
State the two exact input file paths it reads and the exact directory where it writes executable Acceptance Test files. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -q "plan.md"
  echo "$out" | grep -q "acceptance-tests.md"
  echo "$out" | grep -q "tests/acceptance"
}

@test "F2: I want a TDD inner loop nested inside each Acceptance Test, so that production code grows under red-green-refactor" {
  prompt="The following is the atdd-kit running-atdd-cycle skill definition. \
Explain how the TDD inner loop relates to the ATDD outer loop and what cycle the inner loop follows. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "TDD"
  echo "$out" | grep -qiE "nest|inner|inside"
  echo "$out" | grep -qiE "red.?green|green"
}

@test "F3: I want the Acceptance Test lifecycle driven draft->green->regression, so that test state advances mechanically" {
  prompt="The following is the atdd-kit running-atdd-cycle skill definition. \
List, in order, the Acceptance Test lifecycle states it drives. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qi "draft"
  echo "$out" | grep -qi "green"
  echo "$out" | grep -qi "regression"
}

@test "C4: I want Acceptance Tests scoped per story and TDD tests per unit, so that the two feedback loops stay separated" {
  prompt="The following is the atdd-kit running-atdd-cycle skill definition. \
At what granularity is each Acceptance Test file scoped, and at what granularity are the TDD tests? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qi "story"
  echo "$out" | grep -qi "unit"
}
