#!/usr/bin/env bats
# @covers: skills/skill-fix/SKILL.md
# AC1 (explicit invocation), AC2 (interview Q count static assert),
# AC4 (no Agent tool usage), AC6 (1-line report static assert)

SKILL_FIX_SKILL="skills/skill-fix/SKILL.md"
SKILL_FIX_CMD="commands/skill-fix.md"

# --- AC1: skill-fix exists as a skill and command ---

@test "AC1: skills/skill-fix/SKILL.md exists" {
  [[ -f "$SKILL_FIX_SKILL" ]]
}

@test "AC1: commands/skill-fix.md exists" {
  [[ -f "$SKILL_FIX_CMD" ]]
}

@test "AC1: SKILL.md has name: skill-fix in frontmatter" {
  grep -q '^name: skill-fix' "$SKILL_FIX_SKILL"
}

@test "AC1: SKILL.md has non-empty description (trigger conditions only)" {
  desc=$(grep '^description:' "$SKILL_FIX_SKILL" | sed 's/^description:[[:space:]]*//' | tr -d '"')
  [[ -n "$desc" ]]
}

@test "AC1: SKILL.md has AUTOPILOT-GUARD block" {
  grep -q '<AUTOPILOT-GUARD>' "$SKILL_FIX_SKILL"
}

@test "AC1: explicit invocation path leads to interview" {
  grep -q 'interview' "$SKILL_FIX_SKILL"
}

@test "AC1: implicit trigger requires both skill-name and intent-verb" {
  grep -q 'skill 名' "$SKILL_FIX_SKILL" || grep -qi 'skill name' "$SKILL_FIX_SKILL"
  grep -q '意向動詞\|intent.*verb\|改善\|修正\|直したい' "$SKILL_FIX_SKILL"
}

@test "AC1: one-time confirmation question for implicit trigger" {
  grep -q '確認質問\|confirmation' "$SKILL_FIX_SKILL"
}

# --- AC2: interview Q count static assert (safety net) ---

@test "AC2: SKILL.md defines exactly 3 interview questions (Q1/Q2/Q3)" {
  q_count=$(grep -cE '^\*\*Q[123]\*\*:|Q[123].*どの|Q[123].*本来|Q[123].*再現' "$SKILL_FIX_SKILL" || true)
  [[ "$q_count" -ge 3 ]]
}

@test "AC2: Q1 asks which skill/phase was unexpected" {
  grep -q 'Q1' "$SKILL_FIX_SKILL"
}

@test "AC2: Q2 asks expected behavior" {
  grep -q 'Q2' "$SKILL_FIX_SKILL"
}

@test "AC2: Q3 asks reproduction information" {
  grep -q 'Q3' "$SKILL_FIX_SKILL"
}

@test "AC2: no additional questions beyond Q3" {
  grep -qE 'Q4|追加質問は出さない|no additional questions' "$SKILL_FIX_SKILL"
}

# --- AC4: subagent dispatch does not use Agent tool ---

@test "AC4: SKILL.md does not reference 'Agent tool' for dispatch" {
  ! grep -q 'Agent tool.*dispatch\|dispatch.*Agent tool' "$SKILL_FIX_SKILL"
}

@test "AC4: SKILL.md uses Skill tool chain for subagent" {
  grep -q 'Skill tool\|skill-fix.*subagent\|subagent.*Skill tool' "$SKILL_FIX_SKILL"
}

@test "AC4: subagent uses isolation: worktree and run_in_background" {
  grep -q 'isolation.*worktree\|worktree.*isolation' "$SKILL_FIX_SKILL"
  grep -q 'run_in_background' "$SKILL_FIX_SKILL"
}

# --- AC6: 1-line report static assert (safety net) ---

@test "AC6: SKILL.md defines 1-line report format at phase boundary" {
  grep -q 'skill-fix #N:\|1 行\|1-line report\|phase 遷移\|phase boundary' "$SKILL_FIX_SKILL"
}

@test "AC6: success report pattern is defined" {
  grep -q 'ready-to-go' "$SKILL_FIX_SKILL"
}

@test "AC6: failure report pattern is defined" {
  grep -q 'blocked-ac\|failed' "$SKILL_FIX_SKILL"
}
