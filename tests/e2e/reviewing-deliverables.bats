#!/usr/bin/env bats
# @covers: skills/reviewing-deliverables/SKILL.md
# Skill E2E Test for the reviewing-deliverables skill (#192 / #179 Step B5).
# Invokes real `claude -p` (single-turn) and verifies the LLM correctly
# recovers the behavior aspects encoded in SKILL.md.
#
# 1 file = 1 skill, 1 @test = 1 User Story (Connextra form).
# User Stories derived from #192 AC (Step B5).
#
# Prompts ask the LLM to respond in English so the grep-based assertions stay
# stable. This is unrelated to the skill's output language policy.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/reviewing-deliverables/SKILL.md"
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

@test "F1: I want every deliverable reviewed by its specialist subagent, so that PRD/US/Plan/Code/AT each get expert scrutiny" {
  prompt="The following is the atdd-kit reviewing-deliverables skill definition. \
List the reviewer subagents it invokes, by name. Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qi "prd-reviewer"
  echo "$out" | grep -qi "us-reviewer"
  echo "$out" | grep -qi "plan-reviewer"
  echo "$out" | grep -qi "code-reviewer"
  echo "$out" | grep -qi "at-reviewer"
  echo "$out" | grep -qi "final-reviewer"
}

@test "F2: I want the reviewers run one at a time, so that subagent contexts stay isolated and cross-talk is avoided" {
  prompt="The following is the atdd-kit reviewing-deliverables skill definition. \
Does it run the reviewer subagents in parallel or serially (one at a time)? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "serial|sequential|one at a time|one-at-a-time"
}

@test "F3: I want runtime behavior verification handled by Acceptance Tests, so that no manual click-through is mandated" {
  prompt="The following is the atdd-kit reviewing-deliverables skill definition. \
How is runtime behavior verified during review — by mandatory manual testing or by Acceptance Tests? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "acceptance test"
  echo "$out" | grep -qiE "not (require|mandat|force)|no manual|without manual|not mandatory"
}

@test "C1: I want the final reviewer to aggregate the specialist verdicts, so that one PASS/FAIL determination emerges" {
  prompt="The following is the atdd-kit reviewing-deliverables skill definition. \
What does the final-reviewer subagent do with the specialist verdicts? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "aggregat|combin|consolidat"
  echo "$out" | grep -qiE "PASS|FAIL"
}
