#!/usr/bin/env bats
# @covers: skills/autopilot/SKILL.md
# Skill E2E Test for the autopilot skill (autopilot orchestrator, #246).
# Invokes real `claude -p` (single-turn) and verifies the LLM correctly recovers
# the behavior aspects encoded in SKILL.md.
#
# 1 file = 1 skill, 1 @test = 1 User Story (Connextra form).
# User Stories derived from docs/issues/246-autopilot-revival/user-stories.md.
#
# Prompts ask the LLM to respond in English so the grep-based assertions stay
# stable. This is unrelated to the skill's output language policy.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/autopilot/SKILL.md"
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

@test "F1: I want human involvement narrowed to three gates (requirements, design, merge), so that ATDD runs only after I approve the design" {
  prompt="The following is the atdd-kit autopilot (autopilot) skill definition. \
Under this skill, at which points does a human stay involved in the loop? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "requirement|PRD|approv"
  echo "$out" | grep -qiE "design"
  echo "$out" | grep -qiE "merge"
}

@test "F2: I want a satisfaction oracle, so that a deliverable advances only when objectively converged" {
  prompt="The following is the atdd-kit autopilot (autopilot) skill definition. \
What is the condition (the satisfaction oracle) for a deliverable to count as done and advance to the next step? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "AND|all of|both"
  echo "$out" | grep -qiE "acceptance test|AT|green"
  echo "$out" | grep -qiE "verdict|correct|finding"
}

@test "F3: I want the loop to fail safe, so that non-convergence escalates to a human instead of looping forever" {
  prompt="The following is the atdd-kit autopilot (autopilot) skill definition. \
What does the loop do when it cannot converge — repeated identical failures, no progress, or too many iterations? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "escalat|halt|human|stop"
  echo "$out" | grep -qiE "iteration|sameness|stuck|debt"
}

@test "F4: I want the autopilot Iron Law to override the standard one, so that AC-anchored autonomy is legitimate" {
  prompt="The following is the atdd-kit autopilot (autopilot) skill definition. \
Under autopilot, how is the standard rule 'no implementation without human-approved ACs' handled? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "immutable|anchor|approved AC|override|AL-2|iron law"
}

@test "US-1 (#275): I want gate re-presentations to carry the diff inline, so that I can judge without asking for it" {
  prompt="The following is the atdd-kit autopilot (autopilot) skill definition. \
You are at the design-approval gate, re-presenting the deliverables after fixing rejection findings. What must the gate message body itself contain, and in which channels? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "diff (hunk|block)|inline"
  echo "$out" | grep -qiE "per[- ]finding|each finding|key line"
  echo "$out" | grep -qiE "in-session|terminal|GitHub|gate comment"
}

@test "C1: I want the flow skills left unchanged, so that autopilot only changes their role in this mode" {
  prompt="The following is the atdd-kit autopilot (autopilot) skill definition. \
Does this skill permanently rewrite the existing flow skills, or do they keep their normal behavior outside autopilot? Respond in English.

--- SKILL.md START ---
${SKILL_CONTENT}
--- SKILL.md END ---"
  out=$(_run_claude "$prompt")
  [ -n "$out" ]
  echo "$out" | grep -qiE "not permanently|does not|do not|only|unchanged|outside autopilot"
}
