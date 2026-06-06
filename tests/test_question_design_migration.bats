#!/usr/bin/env bats
# @covers: docs/**
# AC1 / AC2 / AC3 / AC6 / AC7: Question design migration tests
# Verifies that skill-authoring-guide.md exists with all required content,
# that SKILL.md files use AskUserQuestion at key decision points,
# and that old inline selection patterns are removed from key decision points.

# --- AC1: docs/guides/skill-authoring-guide.md existence and content ---

@test "AC1: docs/guides/skill-authoring-guide.md exists" {
  [ -f docs/guides/skill-authoring-guide.md ]
}

@test "AC1(a): Closed Question priority principle is documented" {
  grep -qiE 'closed.question|Recommended.*first|Recommended.*必須' docs/guides/skill-authoring-guide.md
}

@test "AC1(b): AskUserQuestion 2-4 options constraint is documented" {
  grep -qiE '2.{0,5}4.{0,10}(option|選択肢)|2 to 4' docs/guides/skill-authoring-guide.md
}

@test "AC1(b): header length constraint (12) is documented" {
  grep -qiE 'header.{0,10}12|12.{0,10}(char|文字)' docs/guides/skill-authoring-guide.md
}

@test "AC1(b): label word limit (5) is documented" {
  grep -qiE 'label.{0,10}5.{0,10}(word|語)|5.{0,10}word' docs/guides/skill-authoring-guide.md
}

@test "AC1(b): multiSelect is documented" {
  grep -qiE 'multiSelect|multi.select' docs/guides/skill-authoring-guide.md
}

@test "AC1(b): Other option auto-inclusion is documented" {
  grep -qiE 'Other.{0,20}(auto|自動)|auto.{0,20}Other' docs/guides/skill-authoring-guide.md
}

@test "AC1(c): Other fallback behavior is documented" {
  grep -qiE 'Other.{0,30}(fallback|free.input|自由入力)|fallback.{0,30}Other' docs/guides/skill-authoring-guide.md
}

@test "AC1(d): 5+ options exception rule is documented" {
  grep -qiE '5.{0,20}(option|選択肢).{0,30}(split|分割|exception)|split.{0,20}question' docs/guides/skill-authoring-guide.md
}

@test "AC1(e): Free-text field exclusions are documented" {
  grep -qiE '(free.text|free.form|自由記述|Issue.*title|bug.*symptom)' docs/guides/skill-authoring-guide.md
}

@test "AC1(f): defining-requirements decision points are listed" {
  grep -qiE 'defining-requirements.*key decision points' docs/guides/skill-authoring-guide.md
  grep -qiE 'task.type|approach' docs/guides/skill-authoring-guide.md
}

@test "AC1(f): writing-plan-and-tests decision points are listed" {
  grep -qiE 'writing-plan-and-tests.*key decision points' docs/guides/skill-authoring-guide.md
  grep -qiE 'test.layer' docs/guides/skill-authoring-guide.md
}

@test "AC1(f): bug decision points are listed" {
  grep -qiE 'bug.*key decision points' docs/guides/skill-authoring-guide.md
  grep -qiE 'fix.proposal|Fix Proposal' docs/guides/skill-authoring-guide.md
}

@test "AC1(g): language policy is documented" {
  grep -qiE 'i18n|DEVELOPMENT\.md|language.policy|English.only' docs/guides/skill-authoring-guide.md
}

# --- AC3: SKILL.md new pattern presence ---

@test "AC3: bug SKILL.md contains AskUserQuestion" {
  grep -q 'AskUserQuestion' skills/bug/SKILL.md
}

# AC3 + bats AC10 co-existence: Recommended pattern must still be present
# (required for test_interaction_reduction.bats AC10 compatibility)

@test "AC3: bug SKILL.md still contains Recommended pattern" {
  grep -qiE 'Recommended' skills/bug/SKILL.md
}

# --- AC6: old inline selection patterns removed from key decision points ---
# Note: patterns use exact space-separated form to avoid matching template placeholders
# like "[A / B / C]" (Bug Flow root cause classification template) which are NOT old selection UI.

@test "AC6: bug SKILL.md has no old arrow proceed pattern" {
  run grep -F '-> Proceed with fix?' skills/bug/SKILL.md
  [ "$status" -ne 0 ]
}

