#!/usr/bin/env bats
# @covers: skills/express/SKILL.md
# Unit Test for the express skill (#284).
# Per `docs/guides/testing-skills.md` (#222), this is a Unit Test — `claude` is
# not invoked; structural / wording-level invariants are checked via grep.
# LLM behavior is covered by the companion Skill E2E Test at `tests/e2e/express.bats`.
#
# Scope: trivial docs-grade fast-path skill re-introduction.
#   - explicit-only invocation (no keyword auto-trigger)
#   - Issue-number validation (required + not-found + closed + in-progress)
#   - APPROVAL-GATE for user activation consent
#   - OK / NG criteria documentation + full-flow fallback
#   - no intermediate artifacts under docs/issues/
#   - express-mode label + ## Express Mode PR body section
#   - scope-overflow abort + full-flow fallback
#   - HARD-GATE for CI; no automatic gh pr merge
#   - atdd-kit-itself: version bump + CHANGELOG mandatory
#   - SKILL.md <= 200 lines, exactly 1 APPROVAL-GATE

SKILL_FILE="skills/express/SKILL.md"

# --- frontmatter ---

@test "frontmatter: name is express" {
  grep -q '^name: express' "$SKILL_FILE"
}

@test "frontmatter: description declares explicit invocation only" {
  grep -q 'explicitly' "$SKILL_FILE"
}

# --- AT-001: Issue-driven guard ---

@test "issue guard: Issue number is required (STOP if missing)" {
  grep -qiE 'issue.*required|Issue number required' "$SKILL_FILE"
}

@test "issue guard: not-found Issue triggers STOP" {
  grep -qiE 'not found' "$SKILL_FILE"
}

@test "issue guard: closed Issue triggers STOP" {
  grep -qiE 'closed' "$SKILL_FILE"
}

@test "issue guard: in-progress Issue triggers STOP" {
  grep -q 'in-progress' "$SKILL_FILE"
}

# --- AT-002: APPROVAL-GATE ---

@test "activation: APPROVAL-GATE block exists" {
  grep -q '<APPROVAL-GATE>' "$SKILL_FILE"
}

@test "activation: explicit user approval is required" {
  grep -qiE 'explicit.*approv|approv.*explicit|user.*approv|Do NOT start implementation until' "$SKILL_FILE"
}

# --- AT-003: Applicability criteria ---

@test "criteria: OK examples include docs/README and typo" {
  grep -qiE 'typo|README|docs' "$SKILL_FILE"
}

@test "criteria: NG examples include new feature and behavior change" {
  grep -qiE 'new feature|behavior change|New feature|Behavior change' "$SKILL_FILE"
}

@test "criteria: defining-requirements fallback for ambiguous cases" {
  grep -q 'defining-requirements' "$SKILL_FILE"
}

# --- AT-004: No intermediate artifacts ---

@test "artifacts: no instructions to create docs/issues PRD/plan/AT files" {
  ! grep -qE 'docs/issues/.*prd\.md|docs/issues/.*user-stories\.md|docs/issues/.*acceptance-tests\.md' "$SKILL_FILE"
}

@test "artifacts: states that no intermediate artifacts are created" {
  grep -qiE 'no.*prd|no intermediate|without.*PRD|no plan|no user.stor|intermediate.*artifact|no acceptance' "$SKILL_FILE"
}

# --- AT-005: PR identification ---

@test "pr: express-mode label is required" {
  grep -q 'express-mode' "$SKILL_FILE"
}

@test "pr: ## Express Mode section is mandatory in PR body" {
  grep -q '## Express Mode' "$SKILL_FILE"
}

@test "pr: guides to setup-github when express-mode label is missing" {
  grep -q 'setup-github' "$SKILL_FILE"
}

# --- AT-007: Scope overflow fallback ---

@test "scope: scope overflow triggers abort and full-flow guidance" {
  grep -qiE 'scope.*overflow|exceeded.*express|exceed.*scope|scope.*exceed|Scope has exceeded' "$SKILL_FILE"
}

@test "scope: scope overflow guides to defining-requirements" {
  grep -q 'defining-requirements' "$SKILL_FILE"
}

@test "scope: Red Flags section exists" {
  grep -qiE 'red flag' "$SKILL_FILE"
}

# --- AT-008: CI gate and human merge ---

@test "ci: HARD-GATE for CI green before merge" {
  grep -q '<HARD-GATE>' "$SKILL_FILE"
}

@test "ci: no automatic gh pr merge in SKILL.md" {
  ! grep -qE '^\s*gh pr merge' "$SKILL_FILE"
}

# --- AT-009: atdd-kit self-target rule ---

@test "self-target: version bump is required for atdd-kit changes" {
  grep -qiE 'version bump|plugin\.json' "$SKILL_FILE"
}

@test "self-target: CHANGELOG update is required for atdd-kit changes" {
  grep -q 'CHANGELOG' "$SKILL_FILE"
}

# --- AT-010: Minimal structure ---

@test "structure: SKILL.md is at most 200 lines" {
  line_count=$(wc -l < "$SKILL_FILE")
  [ "$line_count" -le 200 ]
}

@test "structure: exactly one APPROVAL-GATE" {
  count=$(grep -c '<APPROVAL-GATE>' "$SKILL_FILE")
  [ "$count" -eq 1 ]
}
