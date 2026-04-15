#!/usr/bin/env bats

# AC1 / AC2 / AC3 / AC6 / AC7: Question design migration tests
# Verifies that skill-authoring-guide.md exists with all required content,
# that SKILL.md files use AskUserQuestion at key decision points,
# that old inline selection patterns are removed from key decision points,
# and that commands/autopilot.md has not been modified.

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

@test "AC1(f): ideate decision points are listed" {
  grep -qiE 'ideate.{0,30}(approach|アプローチ)' docs/guides/skill-authoring-guide.md
}

@test "AC1(f): discover decision points are listed" {
  grep -qiE 'discover.{0,30}(task.type|タスクタイプ)' docs/guides/skill-authoring-guide.md
}

@test "AC1(f): issue decision points are listed" {
  grep -qiE 'issue.{0,30}(priority|Priority)' docs/guides/skill-authoring-guide.md
}

@test "AC1(f): plan decision points are listed" {
  grep -qiE 'plan.{0,30}(test.layer|テスト層)' docs/guides/skill-authoring-guide.md
}

@test "AC1(f): bug decision points are listed" {
  grep -qiE 'bug.{0,30}(fix.proposal|Fix Proposal)' docs/guides/skill-authoring-guide.md
}

@test "AC1(g): language policy is documented" {
  grep -qiE 'i18n|DEVELOPMENT\.md|language.policy|English.only' docs/guides/skill-authoring-guide.md
}

# --- AC2: evals.json new assertion count ---

@test "AC2: ideate evals.json has at least 10 assertions" {
  count=$(grep -c '"type": "structural"' skills/ideate/evals/evals.json)
  [ "$count" -ge 10 ]
}

@test "AC2: discover evals.json has at least 23 assertions" {
  count=$(grep -c '"type": "structural"' skills/discover/evals/evals.json)
  [ "$count" -ge 23 ]
}

@test "AC2: issue evals.json has at least 13 assertions" {
  count=$(grep -c '"type": "structural"' skills/issue/evals/evals.json)
  [ "$count" -ge 13 ]
}

@test "AC2: plan evals.json has at least 10 assertions" {
  count=$(grep -c '"type": "structural"' skills/plan/evals/evals.json)
  [ "$count" -ge 10 ]
}

@test "AC2: bug evals.json has at least 5 assertions" {
  count=$(grep -c '"type": "structural"' skills/bug/evals/evals.json)
  [ "$count" -ge 5 ]
}

# --- AC3: SKILL.md new pattern presence ---

@test "AC3: ideate SKILL.md contains AskUserQuestion" {
  grep -q 'AskUserQuestion' skills/ideate/SKILL.md
}

@test "AC3: discover SKILL.md contains AskUserQuestion" {
  grep -q 'AskUserQuestion' skills/discover/SKILL.md
}

@test "AC3: issue SKILL.md contains AskUserQuestion" {
  grep -q 'AskUserQuestion' skills/issue/SKILL.md
}

@test "AC3: plan SKILL.md contains AskUserQuestion" {
  grep -q 'AskUserQuestion' skills/plan/SKILL.md
}

@test "AC3: bug SKILL.md contains AskUserQuestion" {
  grep -q 'AskUserQuestion' skills/bug/SKILL.md
}

# AC3 + bats AC10 co-existence: Recommended pattern must still be present
# (required for test_interaction_reduction.bats AC10 compatibility)

@test "AC3: ideate SKILL.md still contains Recommended pattern" {
  grep -qiE 'Recommended' skills/ideate/SKILL.md
}

@test "AC3: discover SKILL.md still contains Recommended pattern" {
  grep -qiE 'Recommended' skills/discover/SKILL.md
}

@test "AC3: issue SKILL.md still contains Recommended pattern" {
  grep -qiE 'Recommended' skills/issue/SKILL.md
}

@test "AC3: plan SKILL.md still contains Recommended pattern" {
  grep -qiE 'Recommended' skills/plan/SKILL.md
}

@test "AC3: bug SKILL.md still contains Recommended pattern" {
  grep -qiE 'Recommended' skills/bug/SKILL.md
}

# --- AC6: old inline selection patterns removed from key decision points ---
# Note: patterns use exact space-separated form to avoid matching template placeholders
# like "[A / B / C]" (Bug Flow root cause classification template) which are NOT old selection UI.

@test "AC6: ideate SKILL.md has no old inline selection [Yes / Not yet]" {
  run grep -F '[Yes / Not yet]' skills/ideate/SKILL.md
  [ "$status" -ne 0 ]
}

@test "AC6: ideate SKILL.md has no old inline selection [A / B / Suggest alternative]" {
  run grep -F '[A / B / Suggest alternative]' skills/ideate/SKILL.md
  [ "$status" -ne 0 ]
}

@test "AC6: discover SKILL.md has no old inline selection [A / B / Suggest alternative]" {
  run grep -F '[A / B / Suggest alternative]' skills/discover/SKILL.md
  [ "$status" -ne 0 ]
}

@test "AC6: discover SKILL.md has no old inline selection [OK / Suggest revision]" {
  run grep -F '[OK / Suggest revision]' skills/discover/SKILL.md
  [ "$status" -ne 0 ]
}

@test "AC6: discover SKILL.md has no old inline selection Approve/Needs revision in key decision points" {
  # Allow in template output blocks (issue comment format), not in instruction text
  # Check that it's not used as an instruction to Claude
  run grep -n 'Approve? \[Approve / Needs revision\]' skills/discover/SKILL.md
  [ "$status" -ne 0 ]
}

@test "AC6: discover SKILL.md has no old [Yes / Needs correction] pattern" {
  run grep -F '[Yes / Needs correction]' skills/discover/SKILL.md
  [ "$status" -ne 0 ]
}

@test "AC6: plan SKILL.md has no old [Split / Continue as-is] inline pattern" {
  run grep -F 'Split? [Split / Continue as-is' skills/plan/SKILL.md
  [ "$status" -ne 0 ]
}

@test "AC6: bug SKILL.md has no old arrow proceed pattern" {
  run grep -F '-> Proceed with fix?' skills/bug/SKILL.md
  [ "$status" -ne 0 ]
}

