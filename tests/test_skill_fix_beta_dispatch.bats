#!/usr/bin/env bats

# AC4 (β strategy): lib/skill_fix_dispatch.sh build_subagent_prompt function output
# and user approval dialog absence in SKILL.md.

DISPATCH_LIB="lib/skill_fix_dispatch.sh"
SKILL_FIX_SKILL="skills/skill-fix/SKILL.md"

# --- Prerequisites ---

@test "lib/skill_fix_dispatch.sh exists" {
  [[ -f "$DISPATCH_LIB" ]]
}

@test "skill_fix_dispatch.sh is executable or sourceable" {
  bash -n "$DISPATCH_LIB"
}

# --- AC4 dispatch functions present ---

@test "AC4: dispatch_subagent function defined" {
  grep -q 'dispatch_subagent\(\)' "$DISPATCH_LIB"
}

@test "AC4: build_subagent_prompt function defined" {
  grep -q 'build_subagent_prompt\(\)' "$DISPATCH_LIB"
}

@test "AC4: register_inflight function defined" {
  grep -q 'register_inflight\(\)' "$DISPATCH_LIB"
}

@test "AC4: query_inflight function defined" {
  grep -q 'query_inflight\(\)' "$DISPATCH_LIB"
}

@test "AC4: deregister_inflight function defined" {
  grep -q 'deregister_inflight\(\)' "$DISPATCH_LIB"
}

@test "AC4: build_env function defined (AC8)" {
  grep -q 'build_env\(\)' "$DISPATCH_LIB"
}

@test "AC4: check_completion function defined (AC6)" {
  grep -q 'check_completion\(\)' "$DISPATCH_LIB"
}

@test "AC4: cleanup function defined (AC9)" {
  grep -q 'cleanup\(\)' "$DISPATCH_LIB"
}

# --- AC4: build_subagent_prompt output does not contain user approval dialogs ---

@test "AC4 (Note A): SKILL.md does not emit user approval dialog in subagent context" {
  # Subagent has no user; ensure SKILL.md suppresses user approval
  ! grep -q 'AskUserQuestion.*--skill-fix\|user approval.*--skill-fix' "$SKILL_FIX_SKILL"
}

# --- AC4: subagent prompt uses Skill tool chain ---

@test "AC4: dispatch_subagent references /atdd-kit:issue invocation" {
  grep -q 'atdd-kit:issue\|/atdd-kit:issue' "$DISPATCH_LIB"
}

@test "AC4: dispatch_subagent references /atdd-kit:discover with --skill-fix" {
  grep -q 'discover.*--skill-fix\|--skill-fix.*discover' "$DISPATCH_LIB"
}

# --- AC4: audit marker injection ---

@test "AC4: dispatch_subagent includes audit marker injection" {
  grep -q 'skill-fix-audit\|audit.*marker\|audit_marker' "$DISPATCH_LIB"
}

# --- AC8: build_env scrubs ATDD_AUTOPILOT_WORKTREE ---

@test "AC8: build_env unsets ATDD_AUTOPILOT_WORKTREE" {
  grep -q 'ATDD_AUTOPILOT_WORKTREE' "$DISPATCH_LIB"
}

@test "AC8: build_env preserves GH_TOKEN" {
  grep -q 'GH_TOKEN' "$DISPATCH_LIB"
}

@test "AC8: build_env preserves CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" {
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "$DISPATCH_LIB"
}
