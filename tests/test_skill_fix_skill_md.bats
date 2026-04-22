#!/usr/bin/env bats

# SKILL.md drift check + AC2/AC6 static asserts (Note B/C from Plan v2)

SKILL_FIX_SKILL="skills/skill-fix/SKILL.md"

# --- Frontmatter integrity ---

@test "drift: SKILL.md starts with YAML frontmatter" {
  head -1 "$SKILL_FIX_SKILL" | grep -q '^---$'
}

@test "drift: name field is skill-fix" {
  grep -q '^name: skill-fix' "$SKILL_FIX_SKILL"
}

@test "drift: description is trigger-conditions-only (no workflow summary)" {
  desc=$(grep '^description:' "$SKILL_FIX_SKILL" | sed 's/^description:[[:space:]]*//' | tr -d '"')
  # Must not start with "Use when" (workflow summary)
  ! echo "$desc" | grep -qi '^Use when implementing\|^Use to run\|^Drives\|^Executes'
  # Must contain trigger condition markers
  echo "$desc" | grep -qi 'skill.*name\|intent.*verb\|both.*appear\|改善\|skill-fix'
}

# --- AC2 static assert (Note C): 3 interview questions ---

@test "Note C: exactly Q1, Q2, Q3 in SKILL.md (no Q4)" {
  # Must have Q1, Q2, Q3
  grep -q 'Q1' "$SKILL_FIX_SKILL"
  grep -q 'Q2' "$SKILL_FIX_SKILL"
  grep -q 'Q3' "$SKILL_FIX_SKILL"
  # Must NOT have Q4
  ! grep -q '\*\*Q4\*\*\|^Q4:' "$SKILL_FIX_SKILL"
}

@test "Note C: SKILL.md explicitly states no additional questions" {
  grep -q '追加質問は出さない\|no additional questions' "$SKILL_FIX_SKILL"
}

# --- AC6 static assert (Note B): 1-line report ---

@test "Note B: SKILL.md defines 1-line report at phase boundary" {
  grep -q '1 行\|1-line\|phase.*遷移\|phase boundary\|phase transition' "$SKILL_FIX_SKILL"
}

@test "Note B: report format includes issue number" {
  grep -q '#N\|#.*issue\|issue.*#' "$SKILL_FIX_SKILL"
}

@test "Note B: report does not ask for user judgment" {
  grep -q 'ユーザー判断は求めない\|No user judgment\|no user.*judgment' "$SKILL_FIX_SKILL"
}

# --- Required sections present ---

@test "drift: Trigger Conditions section present" {
  grep -q 'Trigger Conditions\|発動条件' "$SKILL_FIX_SKILL"
}

@test "drift: Interview phase section present" {
  grep -q 'Interview\|interview' "$SKILL_FIX_SKILL"
}

@test "drift: Duplicate Check section present" {
  grep -q 'Duplicate Check\|duplicate check' "$SKILL_FIX_SKILL"
}

@test "drift: Subagent Dispatch section present" {
  grep -q 'Subagent Dispatch\|dispatch.*subagent\|Phase 4' "$SKILL_FIX_SKILL"
}

@test "drift: Failure Path section present" {
  grep -q 'Failure Path\|AC9\|FAILED.*BLOCKED.*timeout\|失敗経路' "$SKILL_FIX_SKILL"
}

@test "drift: skill-status output section present" {
  grep -q 'skill-status\|SKILL_STATUS' "$SKILL_FIX_SKILL"
}
