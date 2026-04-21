#!/usr/bin/env bats

# AC8: 3-env inheritance contract (Spike-verified values)
# ATDD_AUTOPILOT_WORKTREE: unset in subagent (Spike: unset)
# CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1: inherited (Spike: 1)
# GH_TOKEN: inherited (Spike: set)

DISPATCH_LIB="lib/skill_fix_dispatch.sh"

# --- AC8: build_env output contract ---

@test "AC8: build_env indicates ATDD_AUTOPILOT_WORKTREE is scrubbed" {
  result=$(bash "$DISPATCH_LIB" build_env)
  echo "$result" | grep -q 'ATDD_AUTOPILOT_WORKTREE'
}

@test "AC8: build_env does NOT pass ATDD_AUTOPILOT_WORKTREE value" {
  # Verify the var is scrubbed, not forwarded with a value
  result=$(ATDD_AUTOPILOT_WORKTREE="/some/path" bash "$DISPATCH_LIB" build_env)
  # Should have SCRUBBED marker, not the actual path
  echo "$result" | grep -q 'ATDD_AUTOPILOT_WORKTREE_SCRUBBED'
  ! echo "$result" | grep -q '/some/path'
}

@test "AC8: build_env passes CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" {
  result=$(CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 bash "$DISPATCH_LIB" build_env)
  echo "$result" | grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1'
}

@test "AC8: build_env passes GH_TOKEN when set" {
  result=$(GH_TOKEN="test-token-abc" bash "$DISPATCH_LIB" build_env)
  echo "$result" | grep -q 'GH_TOKEN=test-token-abc'
}

@test "AC8: build_env omits GH_TOKEN when unset" {
  result=$(GH_TOKEN="" bash "$DISPATCH_LIB" build_env)
  ! echo "$result" | grep -q 'GH_TOKEN='
}

# --- AC8: SKILL.md documents env contract ---

@test "AC8: SKILL.md documents ATDD_AUTOPILOT_WORKTREE not inherited" {
  grep -q 'ATDD_AUTOPILOT_WORKTREE' skills/skill-fix/SKILL.md
}

@test "AC8: SKILL.md documents GH_TOKEN inherited" {
  grep -q 'GH_TOKEN' skills/skill-fix/SKILL.md
}

@test "AC8: SKILL.md documents CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS inherited" {
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' skills/skill-fix/SKILL.md
}
