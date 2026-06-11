#!/usr/bin/env bats
# @covers: skills/reviewing-deliverables/SKILL.md
# Skill E2E Test for the reviewing-deliverables skill (#234 / #179 Step B5).
# Invokes real `claude -p` (single-turn) and verifies the LLM correctly
# recovers the behavior aspects encoded in SKILL.md.
#
# 1 file = 1 skill, 1 @test = 1 User Story (Connextra form).
# User Stories derived from #234 (Workflow-based dynamic parallel review).
#
# Prompts ask the LLM to respond in English so the grep-based assertions stay
# stable. This is unrelated to the skill's output language policy.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/reviewing-deliverables/SKILL.md"
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

@test "F1: I want the reviewer panel generated from the change, so that reviewers fit the deliverable instead of a fixed roster" {
  prompt="The following is the atdd-kit reviewing-deliverables skill definition. \
Is the set of reviewers a fixed predefined roster, or is it generated dynamically from the deliverable content? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "dynamic|generated"
}

@test "F2: I want the reviewers run in parallel, so that the review is not bottlenecked by serial execution" {
  prompt="The following is the atdd-kit reviewing-deliverables skill definition. \
Does it run the reviewers in parallel or serially (one at a time)? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "parallel|concurrent|pipeline"
}

@test "F3: I want non-functional lenses added by risk surface, so that security/performance/usability are covered when relevant" {
  prompt="The following is the atdd-kit reviewing-deliverables skill definition. \
Besides functional correctness, what non-functional review perspectives can it apply, and how are they chosen? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "security"
  echo "$out" | grep -qiE "performance|load"
  echo "$out" | grep -qiE "usability"
}

@test "F4: I want each finding challenged before it counts, so that false positives are suppressed by adversarial verification" {
  prompt="The following is the atdd-kit reviewing-deliverables skill definition. \
What happens to a reviewer's finding before it is included in the verdict? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "adversarial|challenge|refute|verif|majority"
}

@test "F5: I want runtime behavior verification handled by Acceptance Tests, so that no manual click-through is mandated" {
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

@test "C1: I want the final phase to aggregate verified findings, so that one PASS/FAIL determination emerges" {
  prompt="The following is the atdd-kit reviewing-deliverables skill definition. \
What does the final Aggregate phase do with the verified findings? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "aggregat|combin|consolidat"
  echo "$out" | grep -qiE "PASS|FAIL"
}
