#!/usr/bin/env bats
# @covers: skills/launching-preview/SKILL.md
# Unit Test for the launching-preview skill (#194 / #179 Step B7).
# Per `docs/guides/testing-skills.md` (#222), this is a Unit Test — `claude` is
# not invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/launching-preview.bats`.
#
# Scope (per #194 AC): on-demand local preview launcher.
#   - manual invocation form
#   - --port / --no-open argument spec (PRD Open Question #4 resolution)
#   - local only (no global URL)
#   - platform auto-detected from .claude/config.yml

SKILL_FILE="skills/launching-preview/SKILL.md"

# --- Implemented (no longer a skeleton) -----------------------------------

@test "implemented: SKILL.md no longer carries the not-yet-implemented gate" {
  ! grep -q 'not yet implemented' "$SKILL_FILE"
  ! grep -q '<HARD-GATE>' "$SKILL_FILE"
}

# --- Frontmatter ----------------------------------------------------------

@test "frontmatter: description starts with Use when" {
  local desc
  desc=$(grep '^description:' "$SKILL_FILE" | sed 's/^description:[[:space:]]*//' | tr -d '"')
  [[ "$desc" == "Use when"* ]]
}

# --- Invocation form ------------------------------------------------------

@test "invocation: SKILL.md documents the manual invocation form" {
  grep -qE 'claude skill atdd-kit:launching-preview' "$SKILL_FILE"
}

# --- Argument spec (#216 PRD Open Question #4) ----------------------------

@test "args: SKILL.md documents the --port argument" {
  grep -qE '\-\-port' "$SKILL_FILE"
}

@test "args: SKILL.md documents the --no-open argument" {
  grep -qE '\-\-no-open' "$SKILL_FILE"
}

# --- Local only -----------------------------------------------------------

@test "local-only: SKILL.md states preview is local only (no global URL)" {
  grep -qiE 'local only' "$SKILL_FILE"
  grep -qiE 'no global url|global url is (never|not)' "$SKILL_FILE"
}

# --- Platform auto-detect -------------------------------------------------

@test "platform: SKILL.md auto-detects platform from .claude/config.yml" {
  grep -qE '\.claude/config\.yml' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget: SKILL.md is at most 200 lines (#216 PRD design rule)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 200 ]
}

# --- Output language ------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}

# --- Integration ----------------------------------------------------------

@test "integration: SKILL.md has Upstream and Downstream lines" {
  grep -qE '\*\*Upstream:\*\*' "$SKILL_FILE"
  grep -qE '\*\*Downstream:\*\*' "$SKILL_FILE"
}

# --- Persona-less invariant -----------------------------------------------

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}
