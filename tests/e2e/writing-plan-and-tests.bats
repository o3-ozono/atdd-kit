#!/usr/bin/env bats
# @covers: skills/writing-plan-and-tests/SKILL.md
# Skill E2E Test for the writing-plan-and-tests skill (#190 / #179 Step B3).
# Invokes real `claude -p` (single-turn) and verifies the LLM correctly
# recovers the behavior aspects encoded in SKILL.md.
#
# 1 file = 1 skill, 1 @test = 1 User Story (Connextra form).
# User Stories derived from #190 AC (Step B3).
#
# Prompts ask the LLM to respond in English so the grep-based assertions stay
# stable. This is unrelated to the skill's output language policy (Japanese
# fixed for the generated artifacts, see SKILL.md "Output language").

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/writing-plan-and-tests/SKILL.md"
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

@test "F1: I want to turn approved User Stories into a plan and draft Acceptance Tests, so that the ATDD outer loop has concrete targets" {
  prompt="The following is the atdd-kit writing-plan-and-tests skill definition. \
State the exact input file path it reads and the two exact output file paths it writes. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -q "user-stories.md"
  echo "$out" | grep -q "plan.md"
  echo "$out" | grep -q "acceptance-tests.md"
}

@test "F2: I want plan tasks to be 2-5 minute grained with a verify step each, so that the TDD inner loop has checkable units" {
  prompt="The following is the atdd-kit writing-plan-and-tests skill definition. \
What granularity does it require for plan tasks, and what must accompany each task? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qE "2[ -]*(to[ -]*)?5|2.5"
  echo "$out" | grep -qiE "verif"
}

@test "F3: I want the Acceptance Tests to carry a planned->draft->green->regression lifecycle, so that test state is traceable" {
  prompt="The following is the atdd-kit writing-plan-and-tests skill definition. \
List the lifecycle state markers it assigns to Acceptance Test entries. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qi "planned"
  echo "$out" | grep -qi "draft"
  echo "$out" | grep -qi "green"
  echo "$out" | grep -qi "regression"
}

@test "C1: I want a design-doc only when trade-offs or alternatives exist, so that lightweight Issues stay lightweight" {
  prompt="The following is the atdd-kit writing-plan-and-tests skill definition. \
Under what condition does it produce a design-doc, and is it mandatory? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "trade.?off|alternativ"
  echo "$out" | grep -qiE "optional|only when|not (mandatory|required)|conditional"
}
