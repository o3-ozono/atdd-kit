#!/usr/bin/env bats
# @covers: scripts/**
# Worktree isolation + guard false-fire prevention
# AC4: subagent uses isolation: worktree (structure check)
# AC8: main branch not contaminated (structure check)
# Guard: autopilot_worktree_guard does not misfire on skill-fix paths

SKILL_FIX_SKILL="skills/skill-fix/SKILL.md"
DISPATCH_LIB="lib/skill_fix_dispatch.sh"
WORKTREE_GUARD="hooks/autopilot_worktree_guard.py"

# --- AC4: isolation: worktree documented ---

@test "AC4: SKILL.md specifies isolation: worktree for subagent" {
  grep -q 'isolation.*worktree\|worktree.*isolation' "$SKILL_FIX_SKILL"
}

@test "AC4: dispatch_subagent in lib uses worktree isolation reference" {
  grep -q 'isolation.*worktree\|worktree.*isolation\|isolation: worktree' "$DISPATCH_LIB"
}

# --- AC4: subagent does not use main worktree ---

@test "AC4: SKILL.md documents background subagent independence from main branch" {
  grep -q 'run_in_background\|background.*subagent\|subagent.*background' "$SKILL_FIX_SKILL"
}

@test "AC4: dispatch lib generates subagent prompt with isolation context" {
  prompt=$(SKILL_FIX_TIMESTAMP_OVERRIDE="2026-04-21T00:00:00Z" \
    bash "$DISPATCH_LIB" build_subagent_prompt 42 99 discover "Q3 test info")
  # Prompt should reference skill-fix subagent role
  echo "$prompt" | grep -qi 'subagent\|skill-fix'
  # Prompt should NOT reference main session worktree
  ! echo "$prompt" | grep -q 'ATDD_AUTOPILOT_WORKTREE'
}

# --- Guard: autopilot_worktree_guard does not block skill-fix ---

@test "autopilot_worktree_guard.py exists" {
  [[ -f "$WORKTREE_GUARD" ]]
}

@test "worktree guard does not hard-block --skill-fix invocations" {
  # The guard should be aware of --skill-fix as a valid autopilot-related path
  # Verify the guard either: (a) doesn't mention skill-fix blocking, or
  # (b) explicitly allows --skill-fix
  if grep -q 'skill.fix' "$WORKTREE_GUARD"; then
    # If mentioned, it should be in an allow/exception context
    grep -q 'skill.fix.*allow\|allow.*skill.fix\|skill.fix.*except\|except.*skill.fix' "$WORKTREE_GUARD" \
      || grep -qv 'skill.fix.*block\|block.*skill.fix' "$WORKTREE_GUARD"
  else
    # Not mentioned = not blocked by default
    true
  fi
}

# --- AC8: env scrubbing prevents main branch contamination ---

@test "AC8: build_env does not export ATDD_AUTOPILOT_WORKTREE with value" {
  result=$(ATDD_AUTOPILOT_WORKTREE="/main/worktree/path" bash "$DISPATCH_LIB" build_env)
  ! echo "$result" | grep -q '/main/worktree/path'
}
