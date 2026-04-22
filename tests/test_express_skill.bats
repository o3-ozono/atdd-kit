#!/usr/bin/env bats
# @covers: skills/express/SKILL.md
# Tests for Express mode skill (skills/express/SKILL.md)
# All tests are BATS grep-based structural validation

# --- AC1: Input Validation (number / existence / state / lock) ---

@test "AC1-1: SKILL.md has guard for missing issue number" {
  grep -qi 'issue number' skills/express/SKILL.md || grep -qi 'argument' skills/express/SKILL.md
}

@test "AC1-2: SKILL.md uses gh issue view to fetch issue" {
  grep -q 'gh issue view' skills/express/SKILL.md
}

@test "AC1-3: SKILL.md has guard for closed issues" {
  grep -qi 'clos' skills/express/SKILL.md
}

@test "AC1-4: SKILL.md has guard for in-progress lock" {
  grep -q 'in-progress' skills/express/SKILL.md
}

@test "AC1-5: SKILL.md has STOP instruction on validation failure" {
  grep -q 'STOP' skills/express/SKILL.md
}

# --- AC2: Explicit User Approval + Rationale (No Implicit Fallback) ---

@test "AC2-1: SKILL.md has approval gate language (APPROVAL-GATE tag)" {
  grep -q 'APPROVAL-GATE' skills/express/SKILL.md
}

@test "AC2-2: SKILL.md requires rationale input from user" {
  grep -qi 'rationale' skills/express/SKILL.md
}

@test "AC2-3: SKILL.md prohibits implicit fallback without approval" {
  grep -qi 'implicit' skills/express/SKILL.md || grep -qi 'without.*approv' skills/express/SKILL.md
}

# --- AC3: Clean Abort on Approval Rejection ---

@test "AC3-1: SKILL.md has abort/cancel step on rejection" {
  grep -qi 'abort\|cancel\|declin\|reject' skills/express/SKILL.md
}

@test "AC3-2: SKILL.md describes no side effects on abort" {
  grep -qi 'no.*side effect\|clean\|without.*chang\|without.*creat' skills/express/SKILL.md
}

# --- AC4: Applicability Criteria Document (OK/NG) ---

@test "AC4-1: docs/guides/express-mode.md exists" {
  [[ -f "docs/guides/express-mode.md" ]]
}

@test "AC4-2: express-mode.md has OK section" {
  grep -qi '## OK\|## Express OK\|適用 OK\|Applicable\|OK Examples' docs/guides/express-mode.md
}

@test "AC4-3: express-mode.md has NG section" {
  grep -qi '## NG\|## Express NG\|適用 NG\|Not Applicable\|NG Examples' docs/guides/express-mode.md
}

@test "AC4-4: OK section has at least 3 examples" {
  count=$(awk '/## OK|## Express OK|Applicable|OK Examples/{found=1} /## NG|## Express NG|Not Applicable|NG Examples/{found=0} found && /^-/{c++} END{print c}' docs/guides/express-mode.md)
  [[ "$count" -ge 3 ]]
}

@test "AC4-5: NG section has at least 3 examples" {
  count=$(awk '/## NG|## Express NG|Not Applicable|NG Examples/{found=1} /^##[^#]/{if(found && prev_found) found=0; prev_found=found} found && /^-/{c++} END{print c}' docs/guides/express-mode.md)
  [[ "$count" -ge 3 ]]
}

# --- AC5: Issue-driven rule maintained (number required, no skip) ---

@test "AC5-1: SKILL.md requires issue number (no skip path)" {
  grep -qi 'issue number\|issue.*required\|required.*issue' skills/express/SKILL.md
}

@test "AC5-2: SKILL.md does not allow skipping issue number" {
  ! grep -qi 'issue number.*optional\|skip.*issue\|issue number.*not required' skills/express/SKILL.md
}

# --- AC6: CI gate not skippable ---

@test "AC6-1: SKILL.md checks CI with gh pr checks" {
  grep -q 'gh pr checks' skills/express/SKILL.md
}

@test "AC6-2: SKILL.md has CI fail -> STOP guard" {
  grep -qi 'CI.*fail.*STOP\|fail.*do not merge\|fail.*cannot merge\|HARD-GATE' skills/express/SKILL.md
}

@test "AC6-3: SKILL.md has no CI bypass instruction" {
  ! grep -qi 'CI.*can be skipped\|CI.*optional\|may bypass CI\|CI bypass is allowed' skills/express/SKILL.md
}

# --- AC7: PR identification + rationale record + squash merge ---

@test "AC7-1: SKILL.md adds express-mode label to PR" {
  grep -qi 'express-mode' skills/express/SKILL.md
  grep -qi 'add-label' skills/express/SKILL.md
}

@test "AC7-2: SKILL.md adds Express Mode section to PR body" {
  grep -q '## Express Mode' skills/express/SKILL.md
}

@test "AC7-3: SKILL.md records rationale in PR body" {
  grep -qi 'rationale' skills/express/SKILL.md
}

@test "AC7-4: SKILL.md uses squash merge" {
  grep -q 'squash' skills/express/SKILL.md
}

# --- AC8: express-mode label guard ---

@test "AC8-1: setup-github.md or SKILL.md has express-mode label guard/creation" {
  grep -qi 'express-mode' commands/setup-github.md || grep -qi 'label.*not.*exist\|create.*label\|label.*creat' skills/express/SKILL.md
}

# --- AC9: DEVELOPMENT.md mandatory process maintained ---

@test "AC9-1: SKILL.md has version bump instruction" {
  grep -qi 'version bump\|plugin.json\|version.*bump' skills/express/SKILL.md
}

@test "AC9-2: SKILL.md has CHANGELOG update instruction" {
  grep -qi 'CHANGELOG' skills/express/SKILL.md
}

@test "AC9-3: SKILL.md does not allow skipping version bump or CHANGELOG" {
  ! grep -qi 'version bump.*may be skipped\|CHANGELOG.*may be skipped\|version.*not required\|CHANGELOG.*not required' skills/express/SKILL.md
}

# --- AC10: Escalation to autopilot on complexity increase ---

@test "AC10-1: SKILL.md has escalation step for complexity" {
  grep -qi 'escalat\|complex\|scope.*exceed\|beyond.*express' skills/express/SKILL.md
}

@test "AC10-2: SKILL.md references atdd-kit:autopilot for escalation" {
  grep -q 'atdd-kit:autopilot' skills/express/SKILL.md
}
