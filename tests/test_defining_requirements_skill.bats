#!/usr/bin/env bats
# @covers: skills/defining-requirements/SKILL.md
# Skill E2E Test (structural) for the defining-requirements skill
# (#188 / #179 Step B1).
#
# Scope (agreed in #188 discover): assert only the two gates that protect
# v1.0 structural invariants.
#   1. Responsibility boundary — output path, downstream skill name, no subagent spawn
#   2. Line budget — ≤ 200 lines per #216 PRD design rule
# Everything else (PRD section coverage, trigger keyword spec, dialog
# discipline, etc.) is verified by the Skill E2E Test
# (tests/e2e/defining-requirements.bats) so the LLM checks semantics
# rather than brittle wording.

SKILL_FILE="skills/defining-requirements/SKILL.md"

# --- Responsibility boundary ----------------------------------------------

@test "responsibility: SKILL.md declares output at docs/issues/<NNN>/prd.md" {
  grep -q 'docs/issues/<NNN>/prd.md' "$SKILL_FILE"
}

@test "responsibility: SKILL.md cites templates/docs/issues/prd.md as the source template" {
  grep -q 'templates/docs/issues/prd.md' "$SKILL_FILE"
}

@test "responsibility: Downstream is extracting-user-stories (Step 2 ownership)" {
  grep -qE '\*\*Downstream:\*\*[[:space:]]+`extracting-user-stories`' "$SKILL_FILE"
}

@test "responsibility: SKILL.md states subagent spawn is out of scope" {
  grep -qE '\*\*does not\*\* spawn reviewer subagents' "$SKILL_FILE"
}

@test "responsibility: SKILL.md states in-progress label management is out of scope" {
  grep -qE '\*\*does not\*\* add or remove the `in-progress` label' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget: SKILL.md is at most 200 lines (#216 PRD design rule)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 200 ]
}

# --- Draft-PR-based presentation (#267) -------------------------------------
# AT-002: the Flow writes the draft, commits/pushes it as a Draft PR, and only
# then gates approval — the deliverable body travels as the PR diff.

@test "#267 AT-002: Flow order is write draft -> commit/push/Draft PR -> approval gate" {
  local w c g
  w=$(grep -n '\*\*Write draft\.\*\*' "$SKILL_FILE" | head -1 | cut -d: -f1)
  c=$(grep -n 'gh pr create --draft' "$SKILL_FILE" | head -1 | cut -d: -f1)
  g=$(grep -n '\*\*Approval gate' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$w" ] && [ -n "$c" ] && [ -n "$g" ]
  [ "$w" -lt "$c" ]
  [ "$c" -lt "$g" ]
}

@test "#267 AT-002: the pre-approval commit order is mode-independent (no caller-specific carve-out)" {
  # mode-neutral wording — the pin deliberately avoids any orchestrator name
  # so it cannot conflict with the C1 pin in test_autopilot_skill.bats
  grep -qi 'mode-independent' "$SKILL_FILE"
  grep -qi 'regardless of .*caller' "$SKILL_FILE"
}

@test "#267 AT-004: approval gate presents the PR link + decision points only, never the full PRD body" {
  grep -qi 'PR link' "$SKILL_FILE"
  grep -qi 'never the full PRD body' "$SKILL_FILE"
}

@test "#267: revisions re-commit and push so the Draft PR diff stays current" {
  grep -qi 'Draft PR diff stays current' "$SKILL_FILE"
}

# --- #305: User gate selection-UI presentation (one-tap approval) ----------

@test "#305 AT-001: approval gate uses AskUserQuestion with Recommended approval first" {
  grep -q 'AskUserQuestion' "$SKILL_FILE"
  grep -qiE '\(Recommended\).*承認.*ok' "$SKILL_FILE"
}

@test "#305 AT-002: approval gate offers Problem / Outcome / scope send-back options" {
  grep -qiE 'Problem' "$SKILL_FILE"
  grep -qiE 'Outcome' "$SKILL_FILE"
  grep -qiE 'スコープ' "$SKILL_FILE"
}

@test "#305 AT-003: Other option is harness-auto, not manually listed" {
  grep -qiE 'Other.*(harness-auto|手動列挙しない|never list it manually)' "$SKILL_FILE"
}

@test "#305 AT-005: 'recommended.*ok' fallback line present for non-selection-UI channels" {
  grep -qiE "recommended.*ok" "$SKILL_FILE"
  grep -qiE 'fallback' "$SKILL_FILE"
}
