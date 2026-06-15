#!/usr/bin/env bats
# @covers: skills/express/SKILL.md commands/express.md commands/setup-github.md skills/skill-gate/SKILL.md
# Acceptance Tests for Issue #284: express skill (re-introduction)
# AT-001 to AT-010: structural assertions (BATS Unit Test style)
# Corresponds to docs/issues/284-express-skill/acceptance-tests.md

SKILL_FILE="skills/express/SKILL.md"
COMMAND_FILE="commands/express.md"
SETUP_GITHUB_FILE="commands/setup-github.md"
SKILL_GATE_FILE="skills/skill-gate/SKILL.md"

# ---------------------------------------------------------------------------
# AT-001: Command invocation and Issue-driven guard (US-1 / AC1 / AC3)
# ---------------------------------------------------------------------------

@test "AT-001: SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "AT-001: commands/express.md exists" {
  [ -f "$COMMAND_FILE" ]
}

@test "AT-001: SKILL.md description declares explicit-only invocation" {
  grep -q 'explicitly' "$SKILL_FILE" || grep -q 'explicit' "$SKILL_FILE"
}

@test "AT-001: SKILL.md Step 1 has Issue-number-required error branch" {
  grep -qiE 'issue.*required|no.*issue|issue.*missing|Issue number required' "$SKILL_FILE"
}

@test "AT-001: SKILL.md has Issue not-found STOP branch" {
  grep -qiE 'not found' "$SKILL_FILE"
}

@test "AT-001: SKILL.md has closed-Issue STOP branch" {
  grep -qiE 'closed' "$SKILL_FILE"
}

@test "AT-001: SKILL.md has in-progress Issue STOP branch" {
  grep -q 'in-progress' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AT-002: Activation approval gate (US-1 / AC1)
# ---------------------------------------------------------------------------

@test "AT-002: SKILL.md contains <APPROVAL-GATE> block" {
  grep -q '<APPROVAL-GATE>' "$SKILL_FILE"
}

@test "AT-002: APPROVAL-GATE requires explicit user approval" {
  grep -qiE 'approval|explicit.*approv|user.*approv' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AT-003: Criteria documentation and entry judgement (US-2 / AC2)
# ---------------------------------------------------------------------------

@test "AT-003: SKILL.md documents OK examples (docs/README, typo, comments, etc.)" {
  grep -qiE 'typo|README|docs' "$SKILL_FILE"
}

@test "AT-003: SKILL.md documents NG examples (new feature, behavior change, CI change, etc.)" {
  grep -qiE 'new feature|behavior change|CI.*change|dependency|security' "$SKILL_FILE"
}

@test "AT-003: SKILL.md has fallback to defining-requirements for ambiguous cases" {
  grep -q 'defining-requirements' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AT-004: Zero intermediate artifacts — shortest path (US-3)
# ---------------------------------------------------------------------------

@test "AT-004: SKILL.md has no instructions to create docs/issues PRD/plan/AT files" {
  ! grep -qE 'docs/issues/.*prd\.md|docs/issues/.*user-stories\.md|docs/issues/.*acceptance-tests\.md' "$SKILL_FILE"
}

@test "AT-004: SKILL.md states that no intermediate artifacts are created" {
  grep -qiE 'no intermediate|without.*PRD|skip.*intermediate|intermediate.*skip|省略|no.*prd|no.*plan|no.*user.stor' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AT-005: PR identification and rationale recording (US-4 / AC5 / AC6)
# ---------------------------------------------------------------------------

@test "AT-005: SKILL.md describes express-mode label attachment" {
  grep -q 'express-mode' "$SKILL_FILE"
}

@test "AT-005: SKILL.md requires ## Express Mode section in PR body" {
  grep -q '## Express Mode' "$SKILL_FILE"
}

@test "AT-005: SKILL.md guides to setup-github when express-mode label is missing" {
  grep -q 'setup-github' "$SKILL_FILE"
}

@test "AT-005: commands/setup-github.md has express-mode label creation line" {
  grep -q 'express-mode' "$SETUP_GITHUB_FILE"
}

# ---------------------------------------------------------------------------
# AT-006: skill-gate integration (US-5 / AC8)
# ---------------------------------------------------------------------------

@test "AT-006: skill-gate SKILL.md has express routing entry" {
  grep -q 'express' "$SKILL_GATE_FILE"
}

# ---------------------------------------------------------------------------
# AT-007: Scope-overflow fallback to full flow (US-6 / AC9)
# ---------------------------------------------------------------------------

@test "AT-007: SKILL.md describes aborting express on scope overflow" {
  grep -qiE 'scope.*exceed|out.of.scope|fallback.*full|full.*flow|scope.*overflow|exceed.*scope' "$SKILL_FILE"
}

@test "AT-007: SKILL.md guides to defining-requirements on scope overflow" {
  grep -q 'defining-requirements' "$SKILL_FILE"
}

@test "AT-007: SKILL.md has Red Flags section" {
  grep -qiE 'red flag' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AT-008: CI gate and human-only merge (CS-1 / AC4)
# ---------------------------------------------------------------------------

@test "AT-008: SKILL.md contains <HARD-GATE> for CI" {
  grep -q '<HARD-GATE>' "$SKILL_FILE"
}

@test "AT-008: SKILL.md has no automatic gh pr merge command" {
  ! grep -qE '^\s*gh pr merge' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AT-009: DEVELOPMENT.md compliance when atdd-kit is the target (CS-2 / AC7)
# ---------------------------------------------------------------------------

@test "AT-009: SKILL.md requires version bump for atdd-kit-itself changes" {
  grep -qiE 'version bump|plugin\.json' "$SKILL_FILE"
}

@test "AT-009: SKILL.md requires CHANGELOG update" {
  grep -q 'CHANGELOG' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AT-010: Minimal structure and release hygiene (CS-3 / CS-4)
# ---------------------------------------------------------------------------

@test "AT-010: SKILL.md is at most 200 lines" {
  line_count=$(wc -l < "$SKILL_FILE")
  [ "$line_count" -le 200 ]
}

@test "AT-010: SKILL.md has exactly one APPROVAL-GATE" {
  count=$(grep -c '<APPROVAL-GATE>' "$SKILL_FILE")
  [ "$count" -eq 1 ]
}

@test "AT-010: tests/test_express_skill.bats exists" {
  [ -f "tests/test_express_skill.bats" ]
}

@test "AT-010: skills/README.md mentions express" {
  grep -q 'express' "skills/README.md"
}

@test "AT-010: commands/README.md mentions express" {
  grep -q 'express' "commands/README.md"
}

@test "AT-010: tests/README.md mentions test_express_skill" {
  grep -q 'test_express_skill' "tests/README.md"
}

@test "AT-010: CHANGELOG.md has express Added entry (Unreleased or 3.14.0)" {
  grep -qiE 'express' CHANGELOG.md
}

@test "AT-010: plugin.json version matches the topmost CHANGELOG release" {
  # #289 hardening: 旧 literal pin（`version is 3.14.0`）は次の version bump で false-fail し、
  #   post-merge regression を恒久 red にしていた。時点依存の version 文字列を完全一致でピンせず、
  #   CHANGELOG 最新リリース見出しとの一致（将来の bump で壊れない不変条件）で書く。
  top=$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | tr -d '#[] ')
  [ -n "$top" ]
  grep '"version"' .claude-plugin/plugin.json | grep -qF "\"$top\""
}

@test "AT-010: test_skill_structure.bats ALL_SKILLS includes express" {
  grep -q 'express' "tests/test_skill_structure.bats"
}
