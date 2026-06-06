#!/usr/bin/env bats
# @covers: skills/bug/SKILL.md
# Unit Test for the bug skill (#196 / #179 Step C1).
# Per `docs/guides/testing-skills.md` (#222), this is a Unit Test — `claude` is
# not invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at `tests/e2e/bug.bats`.
#
# Scope (per #196 AC): the bug-report pipeline special-flow skill.
#   - auto-trigger keywords
#   - Issue creation without in-progress label
#   - Context Block output
#   - reproduction reads platform from .claude/config.yml
#   - Fix Proposal format
#   - routes into the 6-step flow (defining-requirements, NOT the removed discover)

SKILL_FILE="skills/bug/SKILL.md"

@test "frontmatter: description declares bug auto-trigger" {
  grep -qiE 'Auto-triggers on bug' "$SKILL_FILE"
}

@test "session start: SKILL.md includes a Session Start Check" {
  grep -qE '## Session Start Check' "$SKILL_FILE"
}

@test "intake: SKILL.md asks one question at a time" {
  grep -qiE 'one question at a time' "$SKILL_FILE"
}

@test "issue creation: SKILL.md does NOT add the in-progress label" {
  grep -qiE 'Do NOT add `in-progress` label|not add .*in-progress' "$SKILL_FILE"
}

@test "context block: SKILL.md outputs a Context Block" {
  grep -qE 'Context Block' "$SKILL_FILE"
}

@test "reproduction: SKILL.md reads platform from .claude/config.yml" {
  grep -qE '\.claude/config\.yml' "$SKILL_FILE"
}

@test "fix proposal: SKILL.md defines a Fix Proposal format" {
  grep -qE 'Fix Proposal' "$SKILL_FILE"
}

# --- v1.0 routing (no stale discover reference) ---------------------------

@test "routing: SKILL.md routes into defining-requirements (6-step flow)" {
  grep -qE 'defining-requirements' "$SKILL_FILE"
}

@test "routing: SKILL.md has no stale 'discover' skill reference" {
  ! grep -qiE 'discover' "$SKILL_FILE"
}

# --- Persona-less invariant -----------------------------------------------

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}
